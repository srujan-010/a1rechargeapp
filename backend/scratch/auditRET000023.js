const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

(async () => {
  try {
    const prodUri = process.env.MONGODB_URI;
    console.log('\n====================================================');
    console.log('[COMPLETE FORENSIC INSPECTION FOR RET000023 - MAHESH GANJI]');
    console.log(`Connecting to Production DB: ${prodUri ? prodUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
    console.log('====================================================\n');

    await mongoose.connect(prodUri);
    const prodDb = mongoose.connection.db;

    // Load backup archive
    const archivePath = path.join(__dirname, '../a1recharge_pre_restore_backup_20260901.gz');
    const archiveBuffer = fs.readFileSync(archivePath);
    const archiveData = JSON.parse(zlib.gunzipSync(archiveBuffer).toString('utf-8'));

    const backupUsers = archiveData.collections['users'] || [];
    const backupWallets = archiveData.collections['wallets'] || [];
    const backupRtxs = archiveData.collections['rechargetransactions'] || [];
    const backupLedgers = archiveData.collections['walletledgers'] || [];
    const backupComms = archiveData.collections['commissionhistories'] || [];
    const backupNotifs = archiveData.collections['notifications'] || [];
    const backupAudits = archiveData.collections['auditlogs'] || [];

    const targetUser = backupUsers.find(u => u.retailerId === 'RET000023' || u.phone === '9421729792');

    if (!targetUser) {
      console.error('RET000023 not found in backup users!');
      return;
    }

    const uId = String(targetUser._id);
    console.log(`User Found: ${targetUser.name} (${targetUser.phone}) | ID: ${uId} | RetailerCode: ${targetUser.retailerId || 'RET000023'}\n`);

    // 1. Wallet Record
    const wBackup = backupWallets.find(w => String(w.userId) === uId);
    const wProd = await prodDb.collection('wallets').findOne({ userId: new mongoose.Types.ObjectId(uId) });
    console.log('--- 1. WALLET DOCUMENT ---');
    console.log(`  Backup Wallet : balancePaise=${wBackup ? wBackup.balancePaise : 'N/A'} (₹${wBackup ? (wBackup.balancePaise/100).toFixed(2) : 0}), hold=${wBackup ? wBackup.onHoldPaise : 0}p`);
    console.log(`  Prod Wallet   : balancePaise=${wProd ? wProd.balancePaise : 'N/A'} (₹${wProd ? (wProd.balancePaise/100).toFixed(2) : 0}), hold=${wProd ? wProd.onHoldPaise : 0}p\n`);

    // 2. Recharge Transactions
    const uBackupRtxs = backupRtxs.filter(r => String(r.userId) === uId);
    const uProdRtxs = await prodDb.collection('rechargetransactions').find({ userId: new mongoose.Types.ObjectId(uId) }).toArray();
    console.log('--- 2. RECHARGE TRANSACTIONS ---');
    console.log(`  Backup Recharge Txns (${uBackupRtxs.length}):`);
    uBackupRtxs.forEach((r, idx) => {
      console.log(`    [B${idx+1}] orderId: ${r.orderId} | Amt: ₹${r.amount} | Comm: ₹${r.commissionAmount || 0} | Op: ${r.operatorCode} | Status: ${r.status} | Date: ${r.createdAt}`);
    });

    console.log(`  Prod Recharge Txns (${uProdRtxs.length}):`);
    uProdRtxs.forEach((r, idx) => {
      console.log(`    [P${idx+1}] orderId: ${r.orderId} | Amt: ₹${r.amount} | Comm: ₹${r.commissionAmount || 0} | Op: ${r.operatorCode} | Status: ${r.status} | Date: ${r.createdAt}`);
    });

    // 3. Wallet Ledger Entries (Add Money & Debits)
    const uBackupLedgers = backupLedgers.filter(l => String(l.userId) === uId).sort((a,b) => (new Date(a.createdAt||0)) - (new Date(b.createdAt||0)));
    const uProdLedgers = await prodDb.collection('walletledgers').find({ userId: new mongoose.Types.ObjectId(uId) }).sort({ createdAt: 1 }).toArray();
    console.log('\n--- 3. WALLET LEDGER ENTRIES (ADD MONEY & DEBITS) ---');
    console.log(`  Backup Ledgers (${uBackupLedgers.length}):`);
    uBackupLedgers.forEach((l, idx) => {
      const amtP = l.amountPaise != null ? l.amountPaise : Math.round((l.amount||0)*100);
      console.log(`    [BL${idx+1}] ${l.createdAt} | Type: ${l.transactionType.padEnd(6)} | Amt: ₹${(amtP/100).toFixed(2)} (${amtP}p) | StoredBalAfter: ₹${((l.balanceAfterPaise||0)/100).toFixed(2)} | Ref: ${l.referenceType} | Desc: ${l.description || l.remark || ''}`);
    });

    console.log(`  Prod Ledgers (${uProdLedgers.length}):`);
    uProdLedgers.forEach((l, idx) => {
      const amtP = l.amountPaise != null ? l.amountPaise : Math.round((l.amount||0)*100);
      console.log(`    [PL${idx+1}] ${l.createdAt} | Type: ${l.transactionType.padEnd(6)} | Amt: ₹${(amtP/100).toFixed(2)} (${amtP}p) | StoredBalAfter: ₹${((l.balanceAfterPaise||0)/100).toFixed(2)} | Ref: ${l.referenceType} | Desc: ${l.description || l.remark || ''}`);
    });

    // 4. Notifications Stream for Add Money
    const uNotifs = backupNotifs.filter(n => String(n.userId) === uId);
    console.log(`\n--- 4. NOTIFICATIONS LOG TRAIL (${uNotifs.length}) ---`);
    uNotifs.forEach((n, idx) => {
      console.log(`  [N${idx+1}] ${n.createdAt} | Title: ${n.title} | Order: ${n.relatedOrderId || 'N/A'} | Msg: ${n.message}`);
    });

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
