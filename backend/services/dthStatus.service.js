const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const a1TopupProvider = require('./providers/a1topup/provider.service');
const walletService = require('./wallet/wallet.service');
const commissionService = require('./commission/commission.service');

/**
 * Independent Status Service for DTH Orders
 */
class DthStatusService {
  /**
   * Checks status of a specific DTH order ID against provider and updates database.
   * @param {string} orderId 
   */
  async checkDthStatus(orderId) {
    console.log(`[DTH] Polling Started for Order ID: ${orderId}`);

    const txn = await RechargeTransaction.findOne({ orderId, serviceType: 'dth' });
    if (!txn) {
      throw new Error(`DTH Transaction not found for order ID: ${orderId}`);
    }

    // If already final, return existing state
    if (txn.status === 'SUCCESS' || txn.status === 'FAILED') {
      console.log(`[DTH] Transaction ${orderId} already in final state: ${txn.status}`);
      return {
        orderId: txn.orderId,
        status: txn.status,
        providerStatus: txn.providerStatus,
        providerTransactionId: txn.providerTransactionId,
        operatorReference: txn.operatorReference,
        completedAt: txn.completedAt,
      };
    }

    // Query A1 Provider status API
    let providerRes;
    try {
      providerRes = await a1TopupProvider.status(orderId);
      console.log(`[DTH] Provider Status Response:`, JSON.stringify(providerRes));
    } catch (err) {
      console.error(`[DTH] Status check API error:`, err.message);
      return {
        orderId: txn.orderId,
        status: txn.status,
        message: err.message,
      };
    }

    const newStatus = providerRes.status || 'PENDING';
    const isSuccess = newStatus === 'SUCCESS';
    const isFailed = newStatus === 'FAILED';

    if (newStatus === txn.status) {
      console.log(`[DTH] Status unchanged for Order ${orderId}: ${newStatus}`);
      return {
        orderId: txn.orderId,
        status: txn.status,
        providerStatus: txn.providerStatus,
        providerTransactionId: txn.providerTransactionId || providerRes.providerTransactionId,
        operatorReference: txn.operatorReference || providerRes.operatorReference,
      };
    }

    // Atomic update to ensure no duplicate processing
    const now = new Date();
    const updateDoc = {
      providerStatus: newStatus,
      status: newStatus,
      providerTransactionId: providerRes.providerTransactionId || txn.providerTransactionId,
      operatorReference: providerRes.operatorReference || txn.operatorReference,
    };

    if (isSuccess || isFailed) {
      updateDoc.completedAt = now;
    }

    const updatedTxn = await RechargeTransaction.findOneAndUpdate(
      { _id: txn._id, status: 'PENDING' },
      { $set: updateDoc },
      { new: true }
    );

    if (!updatedTxn) {
      console.log(`[DTH] Concurrent update detected for Order ${orderId}`);
      const latest = await RechargeTransaction.findById(txn._id);
      return {
        orderId: latest.orderId,
        status: latest.status,
        providerStatus: latest.providerStatus,
      };
    }

    let commissionEarnedPaise = 0;
    if (isSuccess) {
      try {
        const commResult = await commissionService.calculateCommission(txn.operatorCode, txn.amount, '', 'dth');
        commissionEarnedPaise = Math.round((commResult.retailerCommissionAmount || 0) * 100);
      } catch (e) {
        console.error(`[DTH] Commission error on status update:`, e.message);
      }
    }

    // Update global Transaction model
    const globalStatus = isSuccess ? 'success' : (isFailed ? 'failed' : 'pending');
    await Transaction.findOneAndUpdate(
      { referenceId: orderId, service: 'dth' },
      {
        $set: {
          status: globalStatus,
          apiReference: providerRes.providerTransactionId || txn.providerTransactionId,
          commissionEarnedPaise,
          ...(isSuccess || isFailed ? { completedAt: now } : {}),
        }
      }
    );

    // Ledger / Wallet settlement
    if (isSuccess) {
      await walletService.commitReservation(txn.userId, txn.amount, commissionEarnedPaise);
      console.log(`[DTH] Polling Complete: Order ${orderId} transitioned to SUCCESS`);
    } else if (isFailed) {
      await walletService.releaseReservation(txn.userId, txn.amount);
      console.log(`[DTH] Polling Complete: Order ${orderId} transitioned to FAILED (wallet hold released)`);
    }

    return {
      orderId: updatedTxn.orderId,
      status: updatedTxn.status,
      providerStatus: updatedTxn.providerStatus,
      providerTransactionId: updatedTxn.providerTransactionId,
      operatorReference: updatedTxn.operatorReference,
      completedAt: updatedTxn.completedAt,
    };
  }
}

module.exports = new DthStatusService();
