const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const a1TopupProvider = require('./providers/a1topup/provider.service');
const dthMappingService = require('./dthMapping.service');
const walletService = require('./wallet/wallet.service');
const notificationService = require('./notification.service');

/**
 * Independent Service for DTH Recharge Execution
 */
class DthRechargeService {
  /**
   * Executes a DTH recharge request through A1 Topup provider.
   */
  async processDthRecharge(options) {
    const { orderId, subscriberId, amount, operator, userId, circleCode } = options;

    console.log(`[DTH] Operator Mapping: Input operator '${operator?.name}' (code: '${operator?.code}', plansInfoCode: '${operator?.plansInfoCode}')`);

    const rechargeTxn = await RechargeTransaction.findOne({ orderId, serviceType: 'dth' });
    const netPayablePaise = rechargeTxn?.netPayablePaise || Math.round((rechargeTxn?.payableAmount || amount) * 100);

    // 1. Convert PlansInfo operator to A1 DTH code
    let mappedOperatorCode;
    try {
      mappedOperatorCode = dthMappingService.getA1DthOperatorCode(operator);
      console.log(`[DTH] Operator Mapped Code for A1: '${mappedOperatorCode}'`);
    } catch (mapErr) {
      console.log(`\nSKIPPED PROVIDER CALL`);
      console.log(`Reason: Operator mapping failure - ${mapErr.message}\n`);

      // Update DB to FAILED due to mapping failure
      await RechargeTransaction.findOneAndUpdate(
        { orderId, serviceType: 'dth' },
        { $set: { status: 'FAILED', providerStatus: 'FAILED', failureReason: mapErr.message, completedAt: new Date() } }
      );
      await Transaction.findOneAndUpdate(
        { referenceId: orderId, service: 'dth' },
        { $set: { status: 'failed', completedAt: new Date() } }
      );
      await walletService.releaseOrderHold({ userId, orderId, netPayablePaise });

      return {
        orderId,
        status: 'FAILED',
        providerTransactionId: '',
        operatorReference: '',
        message: mapErr.message,
      };
    }

    // A1 Payload for DTH
    const providerOptions = {
      orderId,
      mobileNumber: subscriberId,
      amount,
      operatorCode: mappedOperatorCode,
      circleCode: circleCode || '4',
      serviceType: 'DTH',
    };

    console.log(`\n[DTH] Before provider.recharge() for Order ID: ${orderId}`);

    let providerResponse;
    try {
      providerResponse = await a1TopupProvider.recharge(providerOptions);
      console.log(`[DTH] After provider.recharge() for Order ID: ${orderId}`);
      console.log(`[DTH] Normalized provider response:`, JSON.stringify(providerResponse));
    } catch (error) {
      console.error(`[DTH] Provider Exception:`, error.message);
      providerResponse = {
        status: 'FAILED',
        providerTransactionId: '',
        operatorReference: '',
        message: error.message || 'Provider communication failed',
        rawResponse: null,
      };
    }

    const providerStatus = providerResponse.status || 'PENDING';
    const isSuccess = providerStatus === 'SUCCESS';
    const isFailed = providerStatus === 'FAILED';

    console.log(`[DTH PROVIDER STATUS] orderId=${orderId} providerStatus=${providerStatus}`);

    const now = new Date();
    let isWalletFinalized = false;

    // Handle Wallet Finalization BEFORE updating status to SUCCESS
    if (isSuccess && (rechargeTxn?.paymentMethod === 'WALLET' || rechargeTxn?.paymentMethod === 'wallet')) {
      try {
        const settleRes = await walletService.settleWalletOrder({
          userId,
          orderId,
          netPayablePaise
        });
        isWalletFinalized = settleRes.success;
      } catch (commitErr) {
        console.error(`[DTH RESERVATION ERROR] orderId=${orderId} retailerId=${userId} reason=${commitErr.message}`);
      }
    } else if (isSuccess) {
      isWalletFinalized = true; // UPI or non-wallet payment
    }

    const finalStatus = (isSuccess && isWalletFinalized) ? 'SUCCESS' : (isFailed ? 'FAILED' : 'PENDING');
    const globalStatus = (isSuccess && isWalletFinalized) ? 'success' : (isFailed ? 'failed' : 'pending');

    const updatePayload = {
      providerTransactionId: providerResponse.providerTransactionId || '',
      operatorReference: providerResponse.operatorReference || '',
      providerStatus: providerStatus,
      status: finalStatus,
      rawResponse: providerResponse.rawResponse || null,
      ...(finalStatus === 'SUCCESS' || finalStatus === 'FAILED' ? { completedAt: now } : {}),
      ...(isWalletFinalized ? { walletFinalizationStatus: 'COMPLETED', reservationStatus: 'CONSUMED' } : {}),
    };

    const updatedRechargeTxn = await RechargeTransaction.findOneAndUpdate(
      { orderId, serviceType: 'dth' },
      { $set: updatePayload },
      { new: true }
    );

    const updatedGlobalTxn = await Transaction.findOneAndUpdate(
      { referenceId: orderId, service: 'dth' },
      {
        $set: {
          status: globalStatus,
          apiReference: providerResponse.providerTransactionId || '',
          ...(finalStatus === 'SUCCESS' || finalStatus === 'FAILED' ? { completedAt: now } : {}),
        }
      },
      { new: true }
    );

    console.log(`[DTH] Mongo update after provider response: Order ${orderId} updated to status '${finalStatus}'`);

    // Handle Notifications and Commission Logging
    if (finalStatus === 'SUCCESS') {
      const { processSuccessCommission } = require('../controllers/recharge.controller');
      await processSuccessCommission({
        transaction: updatedRechargeTxn || { _id: orderId, orderId, status: 'SUCCESS' },
        globalTransaction: updatedGlobalTxn,
        userId,
        orderId,
        mobileNumber: subscriberId,
        operator,
        operatorCode: operator ? operator.code : 'UNKNOWN',
        amount,
        serviceType: 'dth',
      }).catch(e => console.error('[DTH Commission Process Warning]:', e.message));

      notificationService.notifyRechargeSuccess({
        userId,
        orderId,
        transactionId: providerResponse.providerTransactionId || orderId,
        providerTransactionId: providerResponse.providerTransactionId || '',
        amount,
        operator: operator ? operator.name : 'DTH',
        mobileNumber: subscriberId,
        commissionAmount: (rechargeTxn?.commissionAmountPaise || 0) / 100
      });

      if (rechargeTxn?.commissionAmountPaise > 0) {
        notificationService.notifyCommissionEarned({
          userId,
          commissionAmount: (rechargeTxn?.commissionAmountPaise || 0) / 100
        });
      }
    } else if (isFailed) {
      if (rechargeTxn?.paymentMethod === 'WALLET' || rechargeTxn?.paymentMethod === 'wallet') {
        await walletService.releaseOrderHold({ userId, orderId, netPayablePaise });
      }

      notificationService.notifyRechargeFailed({
        userId,
        orderId,
        transactionId: providerResponse.providerTransactionId || orderId,
        amount,
        operator: operator ? operator.name : 'DTH',
        mobileNumber: subscriberId,
        reason: providerResponse.message || 'DTH recharge failed at operator'
      });
    } else {
      console.log(`[DTH] Order ${orderId} remains PENDING`);

      notificationService.notifyRechargePending({
        userId,
        orderId,
        transactionId: providerResponse.providerTransactionId || orderId,
        providerTransactionId: providerResponse.providerTransactionId || '',
        amount,
        operator: operator ? operator.name : 'DTH',
        mobileNumber: subscriberId
      });
    }

    return {
      orderId,
      status: providerStatus,
      providerTransactionId: providerResponse.providerTransactionId || '',
      operatorReference: providerResponse.operatorReference || '',
      message: providerResponse.message || '',
      completedAt: updatePayload.completedAt || null,
    };
  }
}

module.exports = new DthRechargeService();
