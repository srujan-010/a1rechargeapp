const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const autoTimeoutRefundService = require('../services/autoTimeoutRefund.service');
const RechargeTransaction = require('../models/RechargeTransaction');

async function runSweep() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('[DB CONNECTED] Starting Current Database Timeout Cleanup & Backfill...');

  const now = new Date();
  const cutoff = new Date(now.getTime() - 30 * 60 * 1000);

  const initialPendingCount = await RechargeTransaction.countDocuments({
    status: { $in: ['PENDING', 'pending', 'PROCESSING', 'processing', 'RECHARGE_PROCESSING', 'INITIATED', 'initiated', 'PAYMENT_PENDING', 'payment_pending', 'SUBMITTED', 'submitted'] },
    createdAt: { $lte: cutoff },
  });

  console.log(`[BACKFILL] Found ${initialPendingCount} existing recharge transactions > 30 minutes old.`);

  const summary = await autoTimeoutRefundService.processTimedOutRecharges({
    customCutoffDate: cutoff,
  });

  console.log('\n====================================================');
  console.log('[BACKFILL RESULT]');
  console.log(`Initial Candidates Found: ${summary.candidates}`);
  console.log(`Successfully Marked FAILED: ${summary.failed}`);
  console.log(`Refunds Completed: ${summary.refunded}`);
  console.log(`Already Processed/Terminal Skipped: ${summary.alreadyProcessed}`);
  console.log(`Refund Failures Requiring Retry: ${summary.refundFailures}`);
  console.log('====================================================\n');

  // Verify remaining pending > 30 min
  const remainingCount = await RechargeTransaction.countDocuments({
    status: { $in: ['PENDING', 'pending', 'PROCESSING', 'processing', 'RECHARGE_PROCESSING', 'INITIATED', 'initiated', 'PAYMENT_PENDING', 'payment_pending', 'SUBMITTED', 'submitted'] },
    createdAt: { $lte: cutoff },
  });
  console.log(`[BACKFILL] Overdue pending transactions remaining in DB: ${remainingCount}`);

  await mongoose.disconnect();
}

runSweep().catch(console.error);
