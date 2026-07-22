const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const a1TopupProvider = require('./providers/a1topup/provider.service');
const dthMappingService = require('./dthMapping.service');
const walletService = require('./wallet/wallet.service');
const commissionService = require('./commission/commission.service');

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

    // 4. Update RechargeTransaction in MongoDB
    const now = new Date();
    const updatePayload = {
      providerTransactionId: providerResponse.providerTransactionId || '',
      operatorReference: providerResponse.operatorReference || '',
      providerStatus: providerStatus,
      status: providerStatus,
      rawResponse: providerResponse.rawResponse || null,
    };

    if (isSuccess || isFailed) {
      updatePayload.completedAt = now;
    }

    const updatedRechargeTxn = await RechargeTransaction.findOneAndUpdate(
      { orderId, serviceType: 'dth' },
      { $set: updatePayload },
      { new: true }
    );

    // 5. Update Global Transaction in MongoDB
    const globalTxnStatus = isSuccess ? 'success' : (isFailed ? 'failed' : 'pending');
    await Transaction.findOneAndUpdate(
      { referenceId: orderId, service: 'dth' },
      {
        $set: {
          status: globalTxnStatus,
          apiReference: providerResponse.providerTransactionId || '',
          commissionEarnedPaise,
          ...(isSuccess || isFailed ? { completedAt: now } : {}),
        }
      }
    );

    console.log(`[DTH] Mongo update after provider response: Order ${orderId} updated to status '${providerStatus}'`);

    // 6. Handle Wallet State Transition
    if (isSuccess) {
      // Commit held balance & credit commission
      await walletService.commitReservation(userId, amount, commissionEarnedPaise);
      console.log(`[DTH] Wallet Settlement: Order ${orderId} committed (SUCCESS)`);
    } else if (isFailed) {
      // Release held balance back to available balance
      await walletService.releaseReservation(userId, amount);
      console.log(`[DTH] Wallet Settlement: Order ${orderId} released hold (FAILED)`);
    } else {
      console.log(`[DTH] Wallet Settlement: Order ${orderId} remains PENDING`);
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
