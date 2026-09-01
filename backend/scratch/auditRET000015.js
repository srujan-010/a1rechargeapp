const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

(async () => {
  try {
    const prodUri = process.env.MONGODB_URI;
    console.log('\n====================================================');
    console.log('[READ-ONLY FORENSIC INSPECTION FOR RET000015 - HARSHIT AKULA]');
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

    const targetUser = backupUsers.find(u => u.retailerId === 'RET000015' || u.phone === '9494666060');
    if (!targetUser) {
      console.error('RET000015 not found!');
      return;
    }

    const uId = String(targetUser._id);
    console.log(`User Found: ${targetUser.name} (${targetUser.phone}) | ID: ${uId} | RetailerCode: ${targetUser.retailerId || 'RET000015'}\n`);

    // 1. Backup Recharge Transactions
    const uBackupRtxs = backupRtxs.filter(r => String(r.userId) === uId);
    console.log(`--- 1. BACKUP RECHARGE TRANSACTIONS (${uBackupRtxs.length}) ---`);
    uBackupRtxs.forEach((r, idx) => {
      console.log(`  [B${idx+1}] orderId: ${r.orderId} | Mobile: ${r.mobileNumber} | Amt: ₹${r.amount} | Comm: ₹${r.commissionAmount || 0} | Op: ${r.operatorCode} | Status: ${r.status} | Date: ${r.createdAt}`);
    });

    // 2. Backup Wallet & Ledgers
    const wBackup = backupWallets.find(w => String(w.userId) === uId);
    const uBackupLedgers = backupLedgers.filter(l => String(l.userId) === uId).sort((a,b) => (new Date(a.createdAt||0)) - (new Date(b.createdAt||0)));
    console.log(`\n--- 2. BACKUP WALLET & LEDGERS ---`);
    console.log(`  Backup Wallet Balance: ₹${wBackup ? (wBackup.balancePaise/100).toFixed(2) : 0} (${wBackup ? wBackup.balancePaise : 0}p)`);
    console.log(`  Backup Ledgers (${uBackupLedgers.length}):`);
    uBackupLedgers.forEach((l, idx) => {
      console.log(`    [L${idx+1}] ${l.createdAt} | Type: ${l.transactionType} | Amt: ₹${l.amount || (l.amountPaise/100)} (${l.amountPaise}p) | Ref: ${l.referenceType} | Desc: ${l.description}`);
    });

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
