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
      // Find all transactions that are PENDING in MongoDB
      const pendingTransactions = await RechargeTransaction.find({
        status: 'PENDING'
      }).limit(50); // Process in batches

      if (pendingTransactions.length === 0) {
        this.isRunning = false;
        return;
      }

      console.log(`\n====================================================`);
      console.log(`[Worker] Found ${pendingTransactions.length} pending transactions to verify.`);
      console.log(`====================================================`);

      for (const transaction of pendingTransactions) {
        console.log(`\n----------------------------------------------------`);
        console.log(`[Worker] Processing Pending Transaction:`);
        console.log(`  Mongo Transaction ID: ${transaction._id}`);
        console.log(`  Order ID: ${transaction.orderId}`);
        console.log(`  Current Status: ${transaction.status}`);
        console.log(`----------------------------------------------------`);

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
      // Step 1: Verify Mongo query by looking up document by orderId
      const foundDoc = await RechargeTransaction.findOne({ orderId: transaction.orderId });
      console.log(`\n[Worker] Mongo Query Verification for orderId '${transaction.orderId}':`);
      if (foundDoc) {
        console.log(`  Returned Document ID: ${foundDoc._id}`);
        console.log(`  Returned Status: ${foundDoc.status}`);
      } else {
        console.error(`  ERROR: Query returned NULL. The query is wrong! orderId=${transaction.orderId}`);
        return;
      }

      // Step 2: Query A1 Provider for status lookup
      console.log(`\n[Worker] A1 Lookup:`);
      console.log(`  Order ID: ${transaction.orderId}`);
      const statusResponse = await a1TopupProvider.status(transaction.orderId);
      console.log(`  Provider Response:`, JSON.stringify(statusResponse.rawResponse || statusResponse, null, 2));
      console.log(`  Provider Status: ${statusResponse.status}`);

      const now = new Date();

      if (statusResponse.status === 'SUCCESS') {
        const updateQuery = { _id: transaction._id, status: 'PENDING' };
        const updateFields = {
          $set: {
            status: 'SUCCESS',
            providerStatus: 'SUCCESS',
            providerTransactionId: statusResponse.providerTransactionId || transaction.providerTransactionId,
            operatorReference: statusResponse.operatorReference || transaction.operatorReference,
            completedAt: now,
          }
        };

        // Immediately before updating MongoDB print details
        console.log(`\n====================================================`);
        console.log(`[Worker] Immediately Before Updating MongoDB:`);
        console.log(`  Old Status: ${transaction.status}`);
        console.log(`  New Status: SUCCESS`);
        console.log(`  Query used:`, JSON.stringify(updateQuery));
        console.log(`  Update fields:`, JSON.stringify(updateFields.$set, null, 2));
        console.log(`====================================================`);

        // Atomic State Transition
        const updated = await RechargeTransaction.findOneAndUpdate(
          updateQuery,
          updateFields,
          { new: true }
        );

        const matchedCount = updated ? 1 : 0;
        const modifiedCount = updated ? 1 : 0;

        console.log(`\n[Worker] MongoDB Update Result:`);
        console.log(`  Update Result: ${updated ? 'SUCCESS' : 'SKIPPED (Already resolved)'}`);
        console.log(`  matchedCount: ${matchedCount}`);
        console.log(`  modifiedCount: ${modifiedCount}`);

        if (!updated) {
          console.log(`[Worker] Transaction ${transaction.orderId} already resolved. Skipping further processing.`);
          return;
        }

        // Deduct Wallet & Calculate Commission
        let commissionAmountPaise = 0;
        try {
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
            commissionAmountPaise = commission.retailerCommissionAmount * 100;
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
              amountPaise: commissionAmountPaise,
              status: 'success',
              service: 'commission',
              referenceId: `COM${Date.now()}${Math.floor(Math.random() * 1000)}`,
              description: `Commission for Recharge ${transaction.orderId}`,
              apiReference: transaction._id.toString(),
              paymentMethod: 'wallet',
              completedAt: now,
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
        } catch (walletErr) {
          console.error(`[Worker] Wallet/Commission processing warning for ${transaction.orderId}:`, walletErr.message);
        }

        // Update global Transaction model
        await Transaction.updateOne({ referenceId: transaction.orderId }, { 
          status: 'success', 
          apiReference: statusResponse.providerTransactionId || transaction.providerTransactionId,
          commissionEarnedPaise: commissionAmountPaise,
          completedAt: now,
        });

        await RechargeTransaction.updateOne({ _id: transaction._id }, { commissionCalculated: true });
        console.log(`[Worker] Transaction ${transaction.orderId} marked SUCCESS on both RechargeTransaction and Global Transaction.`);

      } else if (statusResponse.status === 'FAILED') {
        const updateQuery = { _id: transaction._id, status: 'PENDING' };
        const updateFields = {
          $set: {
            status: 'FAILED',
            providerStatus: 'FAILED',
            failureReason: statusResponse.message,
            providerTransactionId: statusResponse.providerTransactionId || transaction.providerTransactionId,
            completedAt: now,
          }
        };

        console.log(`\n====================================================`);
        console.log(`[Worker] Immediately Before Updating MongoDB:`);
        console.log(`  Old Status: ${transaction.status}`);
        console.log(`  New Status: FAILED`);
        console.log(`  Query used:`, JSON.stringify(updateQuery));
        console.log(`  Update fields:`, JSON.stringify(updateFields.$set, null, 2));
        console.log(`====================================================`);

        const updated = await RechargeTransaction.findOneAndUpdate(
          updateQuery,
          updateFields,
          { new: true }
        );

        const matchedCount = updated ? 1 : 0;
        const modifiedCount = updated ? 1 : 0;

        console.log(`\n[Worker] MongoDB Update Result:`);
        console.log(`  Update Result: ${updated ? 'FAILED' : 'SKIPPED (Already resolved)'}`);
        console.log(`  matchedCount: ${matchedCount}`);
        console.log(`  modifiedCount: ${modifiedCount}`);

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
          apiReference: statusResponse.providerTransactionId || transaction.providerTransactionId,
          completedAt: now,
        });

        console.log(`[Worker] Transaction ${transaction.orderId} marked FAILED. Funds refunded.`);
      } else {
        console.log(`[Worker] Transaction ${transaction.orderId} is still PENDING at provider.`);
      }
    } catch (err) {
      console.error(`[Worker] Error processing transaction ${transaction.orderId}:`, err.message);
    }
  }
}

module.exports = new PendingRechargeWorker();
