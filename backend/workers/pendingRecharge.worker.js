const mongoose = require('mongoose');
const RechargeTransaction = require('../models/RechargeTransaction');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');
const walletService = require('../services/wallet/wallet.service');
const commissionService = require('../services/commission/commission.service');
const ledgerService = require('../services/ledger/ledger.service');
const CommissionHistory = require('../models/CommissionHistory');
const Transaction = require('../models/Transaction');

class PendingRechargeWorker {
  constructor() {
    this.intervalId = null;
    this.isRunning = false;
  }

  start(intervalMs = 60000) { // Run every minute by default
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
    this.intervalId = setInterval(() => this.processPending(), intervalMs);
    console.log(`[Worker] Pending Recharge Worker started (Interval: ${intervalMs}ms)`);
  }

  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
      console.log('[Worker] Pending Recharge Worker stopped');
    }
  }

  async processPending() {
    if (this.isRunning) return; // Prevent concurrent overlapping runs
    this.isRunning = true;

    try {
      // Find all transactions that are PENDING and have a providerTransactionId
      // We also check transactions older than 1 minute to avoid checking ones just created
      const oneMinuteAgo = new Date(Date.now() - 60000);
      
      const pendingTransactions = await RechargeTransaction.find({
        status: 'PENDING',
        createdAt: { $lte: oneMinuteAgo }
      }).limit(50); // Process in batches

      if (pendingTransactions.length === 0) {
        this.isRunning = false;
        return;
      }

      console.log(`[Worker] Found ${pendingTransactions.length} pending transactions to verify.`);

      for (const transaction of pendingTransactions) {
        await this.processTransaction(transaction);
      }
    } catch (error) {
      console.error('[Worker] Error in Pending Recharge Worker:', error.message);
    } finally {
      this.isRunning = false;
    }
  }

  async processTransaction(transaction) {
    try {
      // Fetch status directly using orderId (which provider expects as orderid)
      const statusResponse = await a1TopupProvider.status(transaction.orderId);

      if (statusResponse.status === 'SUCCESS') {
        // Atomic State Transition
        const updated = await RechargeTransaction.findOneAndUpdate(
          { _id: transaction._id, status: 'PENDING' },
          { $set: { status: 'SUCCESS', operatorReference: statusResponse.operatorReference } }
        );
        if (!updated) {
          console.log(`[Worker] Transaction ${transaction.orderId} already resolved. Skipping.`);
          return;
        }

        // Deduct Wallet
        await walletService.commitReservation(transaction.userId, transaction.amount);
        
        await ledgerService.logTransaction({
          userId: transaction.userId,
          type: 'DEBIT',
          amount: transaction.amount,
          referenceType: 'RECHARGE',
          referenceId: transaction._id,
          description: `Recharge for ${transaction.mobileNumber} - Order ID: ${transaction.orderId}`,
        });

        // Calculate & Credit Commission
        const commission = await commissionService.calculateCommission(transaction.operatorCode, transaction.amount);
        if (commission.retailerCommissionAmount > 0) {
          await walletService.addBalance(transaction.userId, commission.retailerCommissionAmount);
          await ledgerService.logTransaction({
            userId: transaction.userId,
            type: 'CREDIT',
            amount: commission.retailerCommissionAmount,
            referenceType: 'COMMISSION',
            referenceId: transaction._id,
            description: `Commission for Recharge ${transaction.orderId}`,
          });

          await Transaction.create({
            userId: transaction.userId,
            type: 'credit',
            amountPaise: commission.retailerCommissionAmount * 100,
            status: 'success',
            service: 'commission',
            referenceId: `COM${Date.now()}${Math.floor(Math.random() * 1000)}`,
            description: `Commission for Recharge ${transaction.orderId}`,
            apiReference: transaction._id.toString(),
            paymentMethod: 'wallet',
          });
        }

        await CommissionHistory.create({
          transactionId: transaction._id,
          userId: transaction.userId,
          operatorCode: transaction.operatorCode,
          rechargeAmount: transaction.amount,
          providerCommissionPercentage: commission.providerCommissionPercentage,
          providerCommissionAmount: commission.providerCommissionAmount,
          retailerCommissionPercentage: commission.retailerCommissionPercentage,
          retailerCommissionAmount: commission.retailerCommissionAmount,
          companyProfitPercentage: commission.companyProfitPercentage,
          companyProfitAmount: commission.companyProfitAmount,
        });

        await Transaction.updateOne({ referenceId: transaction.orderId }, { 
          status: 'success', 
          apiReference: statusResponse.providerTransactionId || transaction.providerTransactionId,
          commissionEarnedPaise: commission.retailerCommissionAmount * 100 
        });

        await RechargeTransaction.updateOne({ _id: transaction._id }, { commissionCalculated: true });
        console.log(`[Worker] Transaction ${transaction.orderId} marked SUCCESS`);

      } else if (statusResponse.status === 'FAILED') {
        // Atomic State Transition
        const updated = await RechargeTransaction.findOneAndUpdate(
          { _id: transaction._id, status: 'PENDING' },
          { $set: { status: 'FAILED', failureReason: statusResponse.message } }
        );
        if (!updated) {
          console.log(`[Worker] Transaction ${transaction.orderId} already resolved. Skipping.`);
          return;
        }

        try {
          await walletService.releaseReservation(transaction.userId, transaction.amount);
        } catch (walletError) {
          console.error(`[Worker] Critical Wallet Error for ${transaction.orderId}:`, walletError.message);
        }
        
        await Transaction.updateOne({ referenceId: transaction.orderId }, { 
          status: 'failed', 
          apiReference: statusResponse.providerTransactionId || transaction.providerTransactionId 
        });

        console.log(`[Worker] Transaction ${transaction.orderId} marked FAILED. Funds refunded.`);
      }
      // If still PENDING, do nothing
    } catch (err) {
      console.error(`[Worker] Error processing transaction ${transaction.orderId}:`, err.message);
    }
  }
}

module.exports = new PendingRechargeWorker();
