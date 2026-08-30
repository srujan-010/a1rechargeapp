const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const a1TopupProvider = require('./providers/a1topup/provider.service');
const dthMappingService = require('./dthMapping.service');
const walletService = require('./wallet/wallet.service');
const commissionService = require('./commission/commission.service');
const notificationService = require('./notification.service');

/**
 * Independent Service for DTH Recharge Execution
 */
class DthRechargeService {
  /**
   * Executes a DTH recharge request through A1 Topup provider.
   * 
   * @param {Object} options
   * @param {string} options.orderId - Unique order ID
   * @param {string} options.subscriberId - DTH Subscriber ID / VC Number
   * @param {number} options.amount - Amount in INR
   * @param {Object} options.operator - ProviderOperator document
   * @param {string} options.userId - Mongoose User ObjectId
   * @param {string} [options.circleCode] - Optional circle code
   */
  async processDthRecharge(options) {
    const { orderId, subscriberId, amount, operator, userId, circleCode } = options;

    console.log(`[DTH] Operator Mapping: Input operator '${operator?.name}' (code: '${operator?.code}', plansInfoCode: '${operator?.plansInfoCode}')`);

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
      await walletService.releaseReservation(userId, amount);

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
      mobileNumber: subscriberId, // A1 API uses 'number' query param for subscriberId
      amount,
      operatorCode: mappedOperatorCode,
      circleCode: circleCode || '4', // Fallback to Maharashtra if unspecified
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

    console.log(`[DTH PROVIDER STATUS] orderId=${orderId} providerStatus=${providerStatus} normalizedStatus=${providerStatus}`);

    // 3. Calculate Commission if Success
    let commissionEarnedPaise = 0;
    if (isSuccess) {
      try {
        const commResult = await commissionService.calculateCommission(operator.code, amount, operator.name, 'dth');
        commissionEarnedPaise = Math.round((commResult.retailerCommissionAmount || 0) * 100);
        console.log(`[DTH] Commission Earned: ${commissionEarnedPaise} paise`);
      } catch (commErr) {
        console.error(`[DTH] Commission Calculation Warning: ${commErr.message}`);
      }
    }

    const now = new Date();
    let isWalletFinalized = false;

    // 4. Handle Wallet Finalization BEFORE updating status to SUCCESS
    if (isSuccess) {
      try {
        await walletService.commitOrderReservation({
          userId,
          orderId,
          amount,
          commissionEarnedPaise
        });
        isWalletFinalized = true;
      } catch (commitErr) {
        console.error(`[DTH RESERVATION ERROR] orderId=${orderId} retailerId=${userId} expectedAmount=${amount} reason=${commitErr.message}`);
      }
    }

    // 5. Update RechargeTransaction & Global Transaction
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
          commissionEarnedPaise,
          ...(finalStatus === 'SUCCESS' || finalStatus === 'FAILED' ? { completedAt: now } : {}),
        }
      },
      { new: true }
    );

    console.log(`[DTH] Mongo update after provider response: Order ${orderId} updated to status '${finalStatus}'`);

    // 6. Handle Notifications and Commission Logging
    if (finalStatus === 'SUCCESS') {
      const { processSuccessCommission } = require('../controllers/recharge.controller');
      // Record CommissionHistory & Ledger Credit via processSuccessCommission
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

      const walletAfter = await walletService.getWalletBalance(userId);
      const actualDiff = Number((walletBefore - walletAfter).toFixed(2));

      console.log(`\n[DTH TEST]`);
      console.log(`Gross Recharge: ₹${amount.toFixed(2)}`);
      console.log(`Commission: ₹${(commissionEarnedPaise / 100).toFixed(2)}`);
      console.log(`Net Wallet Debit: ₹${netDebitRupees.toFixed(2)}`);
      console.log(`Wallet Before: ₹${walletBefore.toFixed(2)}`);
      console.log(`Provider Amount: ₹${amount.toFixed(2)}`);
      console.log(`Provider Result: ${providerStatus}`);
      console.log(`Wallet After: ₹${walletAfter.toFixed(2)}`);
      console.log(`Actual Wallet Difference: ₹${actualDiff.toFixed(2)}\n`);

      notificationService.notifyRechargeSuccess({
        userId,
        orderId,
        transactionId: providerResponse.providerTransactionId || orderId,
        providerTransactionId: providerResponse.providerTransactionId || '',
        amount,
        operator: operator ? operator.name : 'DTH',
        mobileNumber: subscriberId,
        commissionAmount: commissionEarnedPaise / 100
      });

      if (commissionEarnedPaise > 0) {
        notificationService.notifyCommissionEarned({
          userId,
          commissionAmount: commissionEarnedPaise / 100
        });
      }
    } else if (isFailed) {
      // Release held balance back to available balance
      await walletService.releaseReservation(userId, amount);
      console.log(`[DTH] Wallet Settlement: Order ${orderId} released hold (FAILED)`);

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
      console.log(`[DTH] Wallet Settlement: Order ${orderId} remains PENDING`);

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
