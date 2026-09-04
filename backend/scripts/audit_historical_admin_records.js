const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGODB_URI;

async function runAudit() {
  try {
    console.log('[HISTORICAL AUDIT] Connecting to database...');
    await mongoose.connect(MONGODB_URI);
    console.log('[HISTORICAL AUDIT] Connected to MongoDB production database.');

    const Transaction = mongoose.model('Transaction', new mongoose.Schema({}, { strict: false }));
    const WalletLedger = mongoose.model('WalletLedger', new mongoose.Schema({}, { strict: false }));
    const AdminAuditLog = mongoose.model('AdminAuditLog', new mongoose.Schema({}, { strict: false }));

    const adminTxns = await Transaction.find({
      $or: [
        { service: { $in: ['admin_credit', 'admin_debit', 'manual_credit', 'manual_debit'] } },
        { paymentMethod: { $in: ['ADMIN', 'SYSTEM', 'system', 'admin'] } },
      ]
    }).lean();

    const auditLogs = await AdminAuditLog.find().lean();
    const ledgerEntries = await WalletLedger.find({
      referenceType: { $in: ['ADMIN_CREDIT', 'ADMIN_DEBIT', 'MANUAL'] }
    }).lean();

    console.log(`[HISTORICAL AUDIT] Found ${adminTxns.length} admin transactions, ${auditLogs.length} admin audit logs, and ${ledgerEntries.length} admin ledger entries.`);

    const report = [];

    ledgerEntries.forEach(l => {
      const suspectedIssues = [];
      const isDebitType = l.transactionType === 'DEBIT';

      if (isDebitType && l.referenceType === 'ADMIN_CREDIT') {
        suspectedIssues.push('ADMIN_DEBIT stored with ADMIN_CREDIT referenceType');
      }
      if (!l.adminId) {
        suspectedIssues.push('Missing adminId');
      }
      if (!l.remark && !l.description) {
        suspectedIssues.push('Missing reason/remark');
      }

      report.push({
        ledgerId: l._id.toString(),
        retailerId: l.userId ? l.userId.toString() : 'UNKNOWN',
        currentType: l.referenceType,
        direction: l.transactionType,
        amountRupees: l.amountPaise ? (l.amountPaise / 100) : l.amount,
        adminId: l.adminId ? l.adminId.toString() : 'UNAVAILABLE',
        reason: l.remark || l.description || 'UNAVAILABLE',
        createdAt: l.createdAt,
        suspectedIssues: suspectedIssues.length > 0 ? suspectedIssues.join('; ') : 'NONE',
      });
    });

    console.log('\n====================================================');
    console.log('[READ-ONLY HISTORICAL FINANCIAL AUDIT REPORT]');
    console.log(JSON.stringify(report, null, 2));
    console.log('====================================================\n');

    process.exit(0);
  } catch (err) {
    console.error('[HISTORICAL AUDIT ERROR]', err);
    process.exit(1);
  }
}

runAudit();
