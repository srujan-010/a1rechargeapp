const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const RechargeTransaction = require('../models/RechargeTransaction');
const reconciliationService = require('../services/reconciliation/reconciliation.service');

async function runAudit() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/a1recharge';
  if (mongoose.connection.readyState === 0) {
    await mongoose.connect(mongoUri);
  }

  console.log('\n====================================================');
  console.log('[FINANCIAL AUDIT & DISCREPANCY REPORT GENERATOR]');
  console.log('====================================================\n');

  const summary = await reconciliationService.reconcileAllWallets();

  // Audit transaction level debits & UPI leakage
  const upiMutations = await RechargeTransaction.find({
    paymentMethod: { $in: ['RAZORPAY_UPI', 'RAZORPAY', 'UPI', 'ONLINE'] },
    walletSettlementStatus: 'SETTLED',
  }).lean();

  console.log(`[UPI LEAKAGE CHECK] Found ${upiMutations.length} non-wallet transactions marked SETTLED.`);

  // Audit duplicate debits
  const walletTransactions = await RechargeTransaction.find({
    paymentMethod: { $in: ['WALLET', 'wallet'] },
    status: 'SUCCESS',
  }).lean();

  const duplicateDebits = [];
  for (const txn of walletTransactions) {
    const debits = await WalletLedger.find({
      referenceType: 'RECHARGE',
      referenceId: txn._id,
      transactionType: 'DEBIT',
    }).lean();

    if (debits.length > 1) {
      duplicateDebits.push({
        orderId: txn.orderId,
        userId: txn.userId,
        debitCount: debits.length,
        debitAmounts: debits.map(d => d.amountPaise),
      });
    }
  }

  console.log(`[DUPLICATE DEBIT CHECK] Found ${duplicateDebits.length} transactions with duplicate debits.`);

  const auditReport = {
    timestamp: new Date().toISOString(),
    walletAuditSummary: summary,
    upiLeakageCount: upiMutations.length,
    upiLeakageOrders: upiMutations.map(t => ({ orderId: t.orderId, userId: t.userId, amountPaise: t.grossAmountPaise })),
    duplicateDebitCount: duplicateDebits.length,
    duplicateDebits,
  };

  console.log('\n====================================================');
  console.log('[AUDIT REPORT GENERATED SUCCESSFULLY]');
  console.log(JSON.stringify(auditReport, null, 2));
  console.log('====================================================\n');

  if (require.main === module) {
    await mongoose.disconnect();
  }
  return auditReport;
}

if (require.main === module) {
  runAudit().catch(err => {
    console.error('Audit Script Error:', err);
    process.exit(1);
  });
}

module.exports = { runAudit };
