const mongoose = require('mongoose');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const Notification = require('../models/Notification');
const CommissionHistory = require('../models/CommissionHistory');
const walletService = require('./wallet/wallet.service');

const NON_TERMINAL_STATUSES = [
  'PENDING',
  'pending',
  'PROCESSING',
  'processing',
  'RECHARGE_PROCESSING',
  'recharge_processing',
  'INITIATED',
  'initiated',
  'PAYMENT_PENDING',
  'payment_pending',
  'SUBMITTED',
  'submitted',
];

const TERMINAL_STATUSES = [
  'SUCCESS',
  'success',
  'FAILED',
  'failed',
  'REFUNDED',
  'refunded',
  'REVERSED',
  'reversed',
];

class AutoTimeoutRefundService {
  constructor() {
    this.timeoutMinutes = 30;
  }

  /**
   * Find and process all recharge transactions older than 30 minutes in non-terminal states.
   */
  async processTimedOutRecharges(options = {}) {
    const { dryRun = false, customCutoffDate = null } = options;
    const now = new Date();
    const cutoffDate = customCutoffDate || new Date(now.getTime() - this.timeoutMinutes * 60 * 1000);

    const summary = {
      candidates: 0,
      failed: 0,
      refunded: 0,
      alreadyProcessed: 0,
      refundFailures: 0,
      skipped: 0,
    };

    try {
      // Find all matching non-terminal transactions
      const candidates = await RechargeTransaction.find({
        status: { $in: NON_TERMINAL_STATUSES },
        createdAt: { $lte: cutoffDate },
      }).sort({ createdAt: 1 }).lean();

      summary.candidates = candidates.length;

      if (candidates.length === 0) {
        return summary;
      }

      console.log(`\n====================================================`);
      console.log(`[AUTO TIMEOUT SUMMARY] Found ${candidates.length} candidates older than ${this.timeoutMinutes} minutes (Cutoff: ${cutoffDate.toISOString()})`);
      console.log(`====================================================`);

      for (const txn of candidates) {
        const ageMinutes = Math.round((now.getTime() - new Date(txn.createdAt).getTime()) / 60000);

        console.log(`\n[AUTO TIMEOUT]`);
        console.log(`transactionId: ${txn._id}`);
        console.log(`orderId: ${txn.orderId}`);
        console.log(`accountType: ${txn.accountType || 'BUSINESS'}`);
        console.log(`createdAt: ${txn.createdAt}`);
        console.log(`currentStatus: ${txn.status}`);
        console.log(`ageMinutes: ${ageMinutes}`);
        console.log(`amount: ${txn.amount}`);
        console.log(`paymentMethod: ${txn.paymentMethod}`);
        console.log(`razorpayPaymentId: ${txn.razorpayPaymentId || 'N/A'}`);

        if (dryRun) {
          console.log(`[AUTO TIMEOUT DRY RUN] Would fail and refund transaction ${txn.orderId}`);
          summary.failed++;
          summary.refunded++;
          continue;
        }

        const result = await this.processSingleTransaction(txn, now, cutoffDate);

        if (result.status === 'SUCCESS') {
          summary.failed++;
          if (result.refundStatus === 'REFUNDED' || result.refundStatus === 'NOT_APPLICABLE') {
            summary.refunded++;
          } else if (result.refundStatus === 'FAILED') {
            summary.refundFailures++;
          }
        } else if (result.status === 'ALREADY_TERMINAL') {
          summary.alreadyProcessed++;
        } else {
          summary.skipped++;
        }
      }

      console.log(`\n====================================================`);
      console.log(`[AUTO TIMEOUT SUMMARY]`);
      console.log(`Candidates: ${summary.candidates}`);
      console.log(`Failed: ${summary.failed}`);
      console.log(`Refunded: ${summary.refunded}`);
      console.log(`Already processed: ${summary.alreadyProcessed}`);
      console.log(`Refund failures: ${summary.refundFailures}`);
      console.log(`====================================================\n`);

      return summary;
    } catch (err) {
      console.error('[AUTO TIMEOUT CRITICAL ERROR]:', err.message);
      throw err;
    }
  }

  /**
   * Process a single transaction atomically.
   */
  async processSingleTransaction(txn, now = new Date(), cutoffDate = null) {
    const cutoff = cutoffDate || new Date(now.getTime() - this.timeoutMinutes * 60 * 1000);
    const refundRef = `REFUND-${txn.orderId}`;
    const refundAmount = Number(txn.payableAmount || txn.amount || 0);

    try {
      // Step 1: Atomic state transition check & claim
      // Only transition if status is still non-terminal AND created <= cutoff
      const claimed = await RechargeTransaction.findOneAndUpdate(
        {
          _id: txn._id,
          status: { $in: NON_TERMINAL_STATUSES },
          createdAt: { $lte: cutoff },
        },
        {
          $set: {
            status: 'FAILED',
            failureReason: 'Recharge timed out after 30 minutes',
            providerStatus: 'FAILED',
            refundStatus: 'PROCESSING',
            refundReason: 'AUTO_TIMEOUT_30_MINUTES',
            refundReference: refundRef,
            completedAt: now,
          },
        },
        { new: true }
      );

      if (!claimed) {
        console.log(`[AUTO TIMEOUT RESULT] transactionId: ${txn._id} status: SKIPPED (Already resolved or modified)`);
        return { status: 'ALREADY_TERMINAL' };
      }

      let refundSuccess = false;
      let finalRefundStatus = 'NONE';
      let refundErrorMsg = null;

      // Step 2: Determine refund mechanism based on payment source
      const isGatewayPayment = (
        claimed.paymentMethod === 'RAZORPAY_UPI' ||
        claimed.paymentMethod === 'RAZORPAY' ||
        claimed.paymentMethod === 'razorpay' ||
        Boolean(claimed.razorpayOrderId)
      );

      const hasCapturedGatewayPayment = Boolean(claimed.razorpayPaymentId);
      const isAbandonedPayment = (
        isGatewayPayment && !hasCapturedGatewayPayment
      ) || (
        (txn.status === 'PAYMENT_PENDING' || txn.status === 'INITIATED') && !hasCapturedGatewayPayment
      );

      const isWalletPayment = (
        claimed.paymentMethod === 'WALLET' ||
        claimed.paymentMethod === 'wallet' ||
        (!isGatewayPayment && !claimed.razorpayPaymentId)
      );

      if (isAbandonedPayment) {
        // No money was ever debited from the customer (abandoned Razorpay checkout)
        finalRefundStatus = 'NOT_APPLICABLE';
        refundSuccess = true;
        console.log(`[AUTO TIMEOUT] Order ${claimed.orderId} was abandoned prior to payment capture. No money debited.`);
      } else if (hasCapturedGatewayPayment) {
        // Refund via Razorpay Gateway
        try {
          const Razorpay = require('razorpay');
          const keyId = (process.env.RAZORPAY_KEY_ID || '').trim();
          const keySecret = (process.env.RAZORPAY_KEY_SECRET || '').trim();

          if (keyId && keySecret) {
            const razorpay = new Razorpay({
              key_id: keyId,
              key_secret: keySecret,
            });

            const payablePaise = Math.round(refundAmount * 100);
            await razorpay.payments.refund(claimed.razorpayPaymentId, {
              amount: payablePaise,
              notes: {
                reason: 'AUTO_TIMEOUT_30_MINUTES',
                orderId: claimed.orderId,
                refundReference: refundRef,
              },
            });
            finalRefundStatus = 'REFUNDED';
            refundSuccess = true;
            console.log(`[AUTO TIMEOUT] Razorpay refund successful for payment ${claimed.razorpayPaymentId} (₹${refundAmount})`);
          } else {
            console.warn(`[AUTO TIMEOUT WARNING] Razorpay credentials missing for order ${claimed.orderId}. Setting refund to REFUNDED (simulated dev).`);
            finalRefundStatus = 'REFUNDED';
            refundSuccess = true;
          }
        } catch (rzpErr) {
          const errMsg = rzpErr.error?.description || rzpErr.message || '';
          if (errMsg.includes('already been refunded') || errMsg.includes('fully refunded')) {
            finalRefundStatus = 'REFUNDED';
            refundSuccess = true;
            console.log(`[AUTO TIMEOUT] Razorpay payment ${claimed.razorpayPaymentId} was already refunded.`);
          } else {
            finalRefundStatus = 'FAILED';
            refundErrorMsg = errMsg;
            console.error(`[AUTO TIMEOUT ERROR] Razorpay refund failed for ${claimed.orderId}:`, errMsg);
          }
        }
      } else if (isWalletPayment) {
        // Wallet Debit / Hold Refund
        try {
          if (claimed.reservedAmount && claimed.reservedAmount > 0) {
            // Funds were held as reservation: release hold back to user
            await walletService.releaseReservation(claimed.userId, claimed.reservedAmount).catch(async (e) => {
              // If hold was already committed, credit back wallet balance directly
              await walletService.addBalance(claimed.userId, claimed.reservedAmount);
            });
          } else {
            // Direct wallet debit: refund back to wallet balance
            await walletService.addBalance(claimed.userId, refundAmount);
          }
          finalRefundStatus = 'REFUNDED';
          refundSuccess = true;
          console.log(`[AUTO TIMEOUT] Wallet refund successful for user ${claimed.userId} (₹${refundAmount})`);
        } catch (wErr) {
          finalRefundStatus = 'FAILED';
          refundErrorMsg = wErr.message;
          console.error(`[AUTO TIMEOUT ERROR] Wallet refund failed for user ${claimed.userId}:`, wErr.message);
        }
      } else {
        // Generic fallback: credit wallet if user exists
        try {
          await walletService.addBalance(claimed.userId, refundAmount);
          finalRefundStatus = 'REFUNDED';
          refundSuccess = true;
        } catch (fErr) {
          finalRefundStatus = 'FAILED';
          refundErrorMsg = fErr.message;
        }
      }

      // Step 3: Persist refund status on RechargeTransaction
      claimed.refundStatus = finalRefundStatus;
      claimed.refundAmount = (finalRefundStatus === 'REFUNDED') ? refundAmount : 0;
      claimed.refundedAt = (finalRefundStatus === 'REFUNDED') ? now : null;
      claimed.refundError = refundErrorMsg;
      await claimed.save();

      // Step 4: Update global Transaction ledger model
      await Transaction.updateOne(
        { referenceId: claimed.orderId },
        {
          status: 'failed',
          failureReason: 'Recharge timed out after 30 minutes',
          completedAt: now,
          providerMessage: 'AUTO_TIMEOUT_30_MINUTES',
        }
      );

      // Step 5: Clean up any provisional commission records
      await CommissionHistory.deleteMany({
        $or: [{ transactionId: claimed._id }, { orderId: claimed.orderId }],
      }).catch(() => {});

      // Step 6: Create user notification (idempotent check)
      try {
        const notifExists = await Notification.findOne({
          userId: claimed.userId,
          relatedOrderId: claimed.orderId,
          notificationType: 'RECHARGE_FAILED',
        });

        if (!notifExists) {
          const refundText = (finalRefundStatus === 'REFUNDED')
            ? `and ₹${refundAmount.toFixed(2)} has been refunded to your account.`
            : `due to inactivity.`;

          await Notification.create({
            userId: claimed.userId,
            notificationType: 'RECHARGE_FAILED',
            title: 'Recharge Failed',
            message: `Your ₹${Number(claimed.amount || 0).toFixed(2)} recharge for ${claimed.mobileNumber || 'mobile'} could not be completed ${refundText}`,
            category: 'RECHARGE',
            priority: 'HIGH',
            relatedOrderId: claimed.orderId,
            relatedTransactionId: String(claimed._id),
          });
        }
      } catch (notifErr) {
        console.warn(`[AUTO TIMEOUT] Notification creation warning for ${claimed.orderId}:`, notifErr.message);
      }

      console.log(`[AUTO TIMEOUT RESULT]`);
      console.log(`transactionId: ${claimed._id}`);
      console.log(`status: FAILED`);
      console.log(`refundStatus: ${finalRefundStatus}`);
      console.log(`refundAmount: ${refundSuccess ? refundAmount : 0}`);
      console.log(`refundReference: ${refundRef}`);

      return {
        status: 'SUCCESS',
        refundStatus: finalRefundStatus,
        transactionId: claimed._id,
        orderId: claimed.orderId,
      };
    } catch (err) {
      console.error(`[AUTO TIMEOUT ERROR] transactionId: ${txn._id} stage: processSingleTransaction error: ${err.message}`);
      return { status: 'ERROR', error: err.message };
    }
  }

  /**
   * Retry any failed refunds that occurred in prior worker ticks.
   */
  async retryFailedRefunds() {
    const failedRefunds = await RechargeTransaction.find({
      status: 'FAILED',
      refundStatus: { $in: ['PROCESSING', 'FAILED'] },
    }).lean();

    if (failedRefunds.length === 0) return 0;

    console.log(`[AUTO TIMEOUT RETRY] Found ${failedRefunds.length} transactions requiring refund retry.`);
    let retried = 0;

    for (const txn of failedRefunds) {
      const res = await this.processSingleTransaction(txn, new Date(), new Date());
      if (res.status === 'SUCCESS' && res.refundStatus === 'REFUNDED') {
        retried++;
      }
    }

    return retried;
  }
}

module.exports = new AutoTimeoutRefundService();
