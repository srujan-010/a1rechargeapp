const mongoose = require('mongoose');
const RechargeTransaction = require('../models/RechargeTransaction');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');
const walletService = require('../services/wallet/wallet.service');
const commissionService = require('../services/commission/commission.service');
const ledgerService = require('../services/ledger/ledger.service');
const CommissionHistory = require('../models/CommissionHistory');
const Transaction = require('../models/Transaction');
const fast2smsService = require('../services/fast2sms.service');

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
      // Find all transactions that are in non-terminal states in MongoDB
      const pendingTransactions = await RechargeTransaction.find({
        status: { $in: ['PENDING', 'PROCESSING', 'RECHARGE_PROCESSING'] }
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
      if (!transaction || !transaction.orderId) {
        console.error('[Worker ERROR] Invalid transaction record or missing orderId. Skipping reconciliation attempt.');
        return;
      }

      // Step 1: Verify Mongo query by looking up document by orderId
      const foundDoc = await RechargeTransaction.findOne({ orderId: transaction.orderId });
      console.log(`\n[Worker] Mongo Query Verification for orderId '${transaction.orderId}':`);
      if (!foundDoc) {
        console.error(`  ERROR: Query returned NULL. orderId=${transaction.orderId}`);
        return;
      }
      console.log(`  Returned Document ID: ${foundDoc._id}`);
      console.log(`  Returned Status: ${foundDoc.status}`);

      if (!foundDoc.providerRequestSent && (foundDoc.paymentMethod === 'RAZORPAY_UPI' || foundDoc.paymentMethod === 'RAZORPAY' || foundDoc.razorpayPaymentId)) {
        console.log(`[Worker] Executing missing A1Topup recharge for order ${foundDoc.orderId}`);
        const rechargeController = require('../controllers/recharge.controller');
        const globalTx = await Transaction.findOne({ referenceId: foundDoc.orderId });
        await rechargeController.dispatchA1TopupRecharge({ transaction: foundDoc, globalTransaction: globalTx, userId: foundDoc.userId });
        return;
      }

      // Step 2: Query A1 Provider for status lookup
      console.log(`\n[Worker] A1 Lookup:`);
      console.log(`  Order ID: ${transaction.orderId}`);
      const statusResponse = await a1TopupProvider.status(transaction.orderId);
      console.log(`  Provider Response:`, JSON.stringify(statusResponse.rawResponse || statusResponse, null, 2));
      console.log(`  Provider Status: ${statusResponse.status}`);

      const safeProviderTxId = (!statusResponse.providerTransactionId || statusResponse.providerTransactionId === 'N/A') ? null : statusResponse.providerTransactionId;
      const now = new Date();

      if (statusResponse.status === 'SUCCESS') {
        const updateQuery = { _id: transaction._id, status: { $in: ['PENDING', 'PROCESSING', 'RECHARGE_PROCESSING', 'INITIATED', 'SUBMITTED'] } };
        const updateFields = {
          $set: {
            status: 'SUCCESS',
            providerStatus: 'SUCCESS',
            providerTransactionId: safeProviderTxId || transaction.providerTransactionId,
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
          const currentDoc = await RechargeTransaction.findById(transaction._id).lean();
          if (currentDoc && (currentDoc.status === 'FAILED' || currentDoc.status === 'REFUNDED')) {
            console.warn(`[RECONCILIATION EXCEPTION] Late provider SUCCESS received for order ${transaction.orderId}. Internal status is ${currentDoc.status} with refundStatus=${currentDoc.refundStatus}. Status preserved as ${currentDoc.status}.`);
          } else {
            console.log(`[Worker] Transaction ${transaction.orderId} already resolved. Skipping further processing.`);
          }
          return;
        }

        // Recharge success WhatsApp message disabled
        console.log('[WHATSAPP] Recharge success message disabled');
        console.log('[WHATSAPP] Template recharge_success / 26992 was NOT sent');

        // Handle Wallet commit / Razorpay confirmation & Calculate Commission
        try {
          const commitAmount = transaction.reservedAmount || transaction.payableAmount || transaction.amount;
          if (transaction.paymentMethod === 'WALLET' || transaction.paymentMethod === 'wallet') {
            await walletService.commitReservation(transaction.userId, commitAmount).catch(e => console.error('[Worker Wallet Commit Warning]:', e.message));
          }
          
          await ledgerService.logTransaction({
            userId: transaction.userId,
            type: 'DEBIT',
            amount: commitAmount,
            referenceType: 'RECHARGE',
            referenceId: transaction._id,
            description: `Recharge for ${transaction.mobileNumber} - Order ID: ${transaction.orderId}`,
          }).catch(() => {});

          // Calculate & Record Commission
          const commission = await commissionService.calculateCommission(transaction.operatorCode, transaction.amount);
          const safeNum = (v) => {
            const n = Number(v);
            return isNaN(n) || !isFinite(n) ? 0 : Number(n.toFixed(2));
          };

          const retailerComm = safeNum(commission?.retailerCommissionAmount);
          const providerComm = safeNum(commission?.providerCommissionAmount);

          if (Number.isFinite(providerComm) && Number.isFinite(retailerComm)) {
            await CommissionHistory.create({
              transactionId: transaction._id,
              userId: transaction.userId,
              operatorCode: String(transaction.operatorCode || 'UNKNOWN'),
              rechargeAmount: safeNum(transaction.amount),
              providerCommissionPercentage: safeNum(commission?.providerCommissionPercentage),
              providerCommissionAmount: providerComm,
              retailerCommissionPercentage: safeNum(commission?.retailerCommissionPercentage),
              retailerCommissionAmount: retailerComm,
              companyProfitPercentage: safeNum(commission?.companyProfitPercentage),
              companyProfitAmount: safeNum(commission?.companyProfitAmount),
            }).catch(commHistErr => {
              console.error(`[Worker] CommissionHistory Save Warning for ${transaction.orderId}:`, commHistErr.message);
            });
          }
        } catch (walletErr) {
          console.error(`[Worker] Wallet/Commission processing warning for ${transaction.orderId}:`, walletErr.message);
        }

        // Update global Transaction model
        await Transaction.updateOne({ referenceId: transaction.orderId }, { 
          status: 'success', 
          apiReference: safeProviderTxId || transaction.orderId,
          completedAt: now,
        });

        await RechargeTransaction.updateOne({ _id: transaction._id }, { commissionCalculated: true });
        console.log(`[Worker] Transaction ${transaction.orderId} marked SUCCESS on both RechargeTransaction and Global Transaction.`);

      } else if (statusResponse.status === 'FAILED') {
        const updateQuery = { _id: transaction._id, status: { $in: ['PENDING', 'PROCESSING', 'RECHARGE_PROCESSING', 'INITIATED', 'SUBMITTED'] } };
        const updateFields = {
          $set: {
            status: 'FAILED',
            providerStatus: 'FAILED',
            failureReason: statusResponse.message,
            providerTransactionId: safeProviderTxId || transaction.providerTransactionId,
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

        if (!updated) {
          console.log(`[Worker] Transaction ${transaction.orderId} already resolved. Skipping.`);
          return;
        }

        const rollbackAmount = transaction.reservedAmount || transaction.payableAmount || transaction.amount;
        if (transaction.paymentMethod === 'WALLET' || transaction.paymentMethod === 'wallet') {
          try {
            await walletService.releaseReservation(transaction.userId, rollbackAmount);
          } catch (walletError) {
            console.error(`[Worker] Critical Wallet Error for ${transaction.orderId}:`, walletError.message);
          }
        } else if (transaction.razorpayPaymentId) {
          // Razorpay UPI Refund
          try {
            const Razorpay = require('razorpay');
            const razorpay = new Razorpay({
              key_id: (process.env.RAZORPAY_KEY_ID || '').trim(),
              key_secret: (process.env.RAZORPAY_KEY_SECRET || '').trim(),
            });
            const payablePaise = Math.round((transaction.payableAmount || transaction.amount) * 100);
            await razorpay.payments.refund(transaction.razorpayPaymentId, {
              amount: payablePaise,
              notes: { reason: 'Recharge failed at provider (poller)', orderId: transaction.orderId },
            });
            transaction.status = 'REFUNDED';
            await transaction.save();
            console.log(`[Worker] Refunded ${payablePaise} paise for Razorpay payment ${transaction.razorpayPaymentId}`);
          } catch (rfErr) {
            console.error(`[Worker] Razorpay Refund Error for ${transaction.orderId}:`, rfErr.message);
          }
        }
        
        await Transaction.updateOne({ referenceId: transaction.orderId }, { 
          status: 'failed', 
          apiReference: safeProviderTxId || transaction.orderId,
          completedAt: now,
        });

        console.log(`[Worker] Transaction ${transaction.orderId} marked FAILED.`);
      } else if (statusResponse.status === 'UNKNOWN') {
        console.warn(`[Worker WARNING] Provider status for ${transaction.orderId} returned UNKNOWN. Reconciliation pending.`);
      } else {
        console.log(`[Worker] Transaction ${transaction.orderId} is still PENDING at provider.`);
      }
    } catch (err) {
      console.error(`[Worker] Error processing transaction ${transaction.orderId}:`, err.message);
    }
  }
}

module.exports = new PendingRechargeWorker();
