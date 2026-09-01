const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

(async () => {
  try {
    const prodUri = process.env.MONGODB_URI;
    console.log('\n====================================================');
    console.log('[READ-ONLY FORENSIC DRY-RUN RESTORATION AUDIT]');
    console.log(`Connecting to Production DB: ${prodUri ? prodUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
    console.log('====================================================\n');

    await mongoose.connect(prodUri);
    const prodDb = mongoose.connection.db;

    // Load original pre-incident backup archive
    const archivePath = path.join(__dirname, '../a1recharge_pre_restore_backup_20260901.gz');
    const archiveBuffer = fs.readFileSync(archivePath);
    const archiveData = JSON.parse(zlib.gunzipSync(archiveBuffer).toString('utf-8'));

    const backupUsers = archiveData.collections['users'] || [];
    const backupRtxs = archiveData.collections['rechargetransactions'] || [];
    const backupLedgers = archiveData.collections['walletledgers'] || [];
    const backupComms = archiveData.collections['commissionhistories'] || [];

    const prodUsers = await prodDb.collection('users').find({}).toArray();
    const prodRtxs = await prodDb.collection('rechargetransactions').find({}).toArray();
    const prodLedgers = await prodDb.collection('walletledgers').find({}).toArray();
    const prodComms = await prodDb.collection('commissionhistories').find({}).toArray();

    // Map backup order IDs
    const backupRtxMap = new Map(backupRtxs.map(r => [r.orderId, r]));
    const prodRtxMap = new Map(prodRtxs.map(r => [r.orderId, r]));

    console.log('--- 1. OVERALL RECORD COUNT COMPARISON ---');
    console.log(`Backup Users          : ${backupUsers.length} | Prod Users: ${prodUsers.length}`);
    console.log(`Backup Rtxs           : ${backupRtxs.length} | Prod Rtxs : ${prodRtxs.length}`);
    console.log(`Backup Wallet Ledgers : ${backupLedgers.length} | Prod Ledgers : ${prodLedgers.length}`);
    console.log(`Backup Commissions    : ${backupComms.length} | Prod Commissions : ${prodComms.length}\n`);

    // Audit RET000035, RET000041, RET000042 specifically
    console.log('--- 2. DETAILED FORENSIC AUDIT FOR RET000035, RET000041, RET000042 ---');
    for (const code of ['RET000035', 'RET000041', 'RET000042']) {
      const uBackup = backupUsers.find(u => u.retailerId === code || u.customId === code);
      const uProd = prodUsers.find(u => u.retailerId === code || u.customId === code);
      const uId = uBackup ? String(uBackup._id) : (uProd ? String(uProd._id) : null);

      console.log(`\nRetailer Code: ${code} (${uBackup ? uBackup.name : 'Unknown'})`);
      if (uId) {
        const uBackupRtxs = backupRtxs.filter(r => String(r.userId) === uId);
        const uProdRtxs = prodRtxs.filter(r => String(r.userId) === uId);

        console.log(`  Backup Recharge Transactions Count : ${uBackupRtxs.length}`);
        console.log(`  Production Recharge Transactions Count: ${uProdRtxs.length}`);

        console.log('  Original Backup Documents (Authoritative Pre-Incident):');
        if (uBackupRtxs.length === 0) {
          console.log('    [NONE IN BACKUP RECHARGETRANSACTIONS COLLECTION]');
        } else {
          uBackupRtxs.forEach(r => {
            console.log(`    orderId: ${r.orderId} | Amt: ₹${r.amount} | Comm: ₹${r.commissionAmount || 0} | Op: ${r.operatorCode} | Status: ${r.status}`);
          });
        }

        console.log('  Current Production Documents:');
        uProdRtxs.forEach(r => {
          const isReconstructed = r.isReconstructedFromEventStream || !backupRtxMap.has(r.orderId);
          console.log(`    orderId: ${r.orderId} | Amt: ₹${r.amount} | Comm: ₹${r.commissionAmount || 0} | Op: ${r.operatorCode} | Status: ${r.status} ${isReconstructed ? '[MANUFACTURED / RECONSTRUCTED]' : '[ORIGINAL PITR]'}`);
        });
      }
    }

    // 3. Field Mismatches Between Original Backup and Current Production
    console.log('\n--- 3. FIELD MISMATCH AUDIT BETWEEN BACKUP & PRODUCTION ---');
    let fieldMismatchCount = 0;
    const mismatches = [];

    for (const bRtx of backupRtxs) {
      const pRtx = prodRtxMap.get(bRtx.orderId);
      if (pRtx) {
        const diffs = [];
        if (bRtx.amount !== pRtx.amount) diffs.push(`amount: backup=${bRtx.amount} vs prod=${pRtx.amount}`);
        if (bRtx.commissionAmount !== pRtx.commissionAmount) diffs.push(`commission: backup=${bRtx.commissionAmount} vs prod=${pRtx.commissionAmount}`);
        if (bRtx.status !== pRtx.status) diffs.push(`status: backup=${bRtx.status} vs prod=${pRtx.status}`);
        if (bRtx.operatorCode !== pRtx.operatorCode) diffs.push(`operatorCode: backup=${bRtx.operatorCode} vs prod=${pRtx.operatorCode}`);

        if (diffs.length > 0) {
          fieldMismatchCount++;
          mismatches.push({ orderId: bRtx.orderId, diffs });
        }
      }
    }

    console.log(`Total Field Mismatches: ${fieldMismatchCount}`);
    mismatches.forEach(m => console.log(`  orderId: ${m.orderId} => ${m.diffs.join(' | ')}`));

    // 4. Manufactured / Reconstructed Orders List
    console.log('\n--- 4. MANUFACTURED / RECONSTRUCTED ORDERS IDENTIFIED IN PRODUCTION ---');
    const manufacturedOrders = prodRtxs.filter(r => !backupRtxMap.has(r.orderId));
    console.log(`Total Manufactured / Reconstructed Orders: ${manufacturedOrders.length}`);
    manufacturedOrders.forEach((m, idx) => {
      console.log(`  [${idx+1}] orderId: ${m.orderId} | User: ${m.userId} | Amt: ₹${m.amount} | Comm: ₹${m.commissionAmount} | Status: ${m.status}`);
    });

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
