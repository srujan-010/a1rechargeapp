const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

(async () => {
  try {
    const prodUri = process.env.MONGODB_URI;
    console.log('\n====================================================');
    console.log('[DEEP RETAILER & TRANSACTION INVENTORY AUDIT]');
    console.log(`Connecting to Production Atlas DB: ${prodUri ? prodUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
    console.log('====================================================\n');

    await mongoose.connect(prodUri);
    const prodDb = mongoose.connection.db;

    // Load backup archive
    const archivePath = path.join(__dirname, '../a1recharge_pre_restore_backup_20260901.gz');
    const archiveBuffer = fs.readFileSync(archivePath);
    const archiveData = JSON.parse(zlib.gunzipSync(archiveBuffer).toString('utf-8'));

    const backupUsers = archiveData.collections['users'] || [];
    const backupRtxs = archiveData.collections['rechargetransactions'] || [];
    const backupLedgers = archiveData.collections['walletledgers'] || [];
    const backupNotifs = archiveData.collections['notifications'] || [];
    const backupAudits = archiveData.collections['auditlogs'] || [];

    const prodUsers = await prodDb.collection('users').find({}).toArray();
    const prodRtxs = await prodDb.collection('rechargetransactions').find({}).toArray();
    const prodLedgers = await prodDb.collection('walletledgers').find({}).toArray();
    const prodNotifs = await prodDb.collection('notifications').find({}).toArray();
    const prodAudits = await prodDb.collection('auditlogs').find({}).toArray();

    console.log(`--- TOTAL COUNTS COMPARISON ---`);
    console.log(`Backup Users: ${backupUsers.length} | Prod Users: ${prodUsers.length}`);
    console.log(`Backup Rtxs : ${backupRtxs.length} | Prod Rtxs : ${prodRtxs.length}`);
    console.log(`Backup Ledg : ${backupLedgers.length} | Prod Ledg : ${prodLedgers.length}`);

    // Audit specific retailers: RET000035, RET000041, RET000042
    const targetRetailerCodes = ['RET000035', 'RET000041', 'RET000042'];
    console.log('\n--- SPECIFIC TARGET RETAILERS (RET000035, RET000041, RET000042) ---');

    for (const code of targetRetailerCodes) {
      const uBackup = backupUsers.find(u => u.retailerId === code || (u.customId && u.customId === code));
      const uProd = prodUsers.find(u => u.retailerId === code || (u.customId && u.customId === code));

      console.log(`\nRetailer Code: ${code}`);
      console.log(`  Backup Record: ${uBackup ? uBackup.name + ' (' + uBackup.phone + ') ID:' + uBackup._id : 'NOT FOUND IN BACKUP USERS'}`);
      console.log(`  Prod Record  : ${uProd ? uProd.name + ' (' + uProd.phone + ') ID:' + uProd._id : 'NOT FOUND IN PROD USERS'}`);

      // Search all backup and prod collections for this retailer
      const targetUserIdStr = uBackup ? String(uBackup._id) : (uProd ? String(uProd._id) : null);
      if (targetUserIdStr) {
        const uBackupRtxs = backupRtxs.filter(r => String(r.userId) === targetUserIdStr);
        const uProdRtxs = prodRtxs.filter(r => String(r.userId) === targetUserIdStr);
        const uBackupNotifs = backupNotifs.filter(n => String(n.userId) === targetUserIdStr);
        const uProdNotifs = prodNotifs.filter(n => String(n.userId) === targetUserIdStr);

        console.log(`  Backup Rech Txns Count: ${uBackupRtxs.length} | Prod Rech Txns Count: ${uProdRtxs.length}`);
        console.log(`  Backup Notifications Count: ${uBackupNotifs.length} | Prod Notifications Count: ${uProdNotifs.length}`);

        console.log('  Recharge Transactions List:');
        uBackupRtxs.forEach((r, idx) => {
          console.log(`    [${idx+1}] orderId: ${r.orderId} | amt: ₹${r.amount || r.grossAmountPaise/100} | status: ${r.status} | method: ${r.paymentMethod} | created: ${r.createdAt}`);
        });

        if (uBackupNotifs.length > 0) {
          console.log('  Notification Event Log Trail:');
          uBackupNotifs.forEach((n, idx) => {
            console.log(`    [N${idx+1}] ${n.createdAt} | ${n.title} | Order: ${n.relatedOrderId || 'N/A'} | Msg: ${n.message}`);
          });
        }
      } else {
        console.log(`  Searching all notifications for retailer code ${code}...`);
        const matchingNotifs = backupNotifs.filter(n => (n.message || '').includes(code) || (n.title || '').includes(code));
        console.log(`  Matching Notifications: ${matchingNotifs.length}`);
        matchingNotifs.forEach(n => console.log('    Notif:', n));
      }
    }

    // Full Retailer Inventory across ALL users
    console.log('\n--- FULL RETAILER-BY-RETAILER TRANSACTION INVENTORY ---');
    console.log('| Retailer Code | User ID | Name | Phone | Backup Rtxs | Prod Rtxs | Ledgers | Notifs | Audits | Status |');
    console.log('|---------------|---------|------|-------|-------------|-----------|---------|--------|--------|--------|');

    let totalBackupRtxs = 0;
    let totalProdRtxs = 0;
    const missingOrdersList = [];

    for (const u of backupUsers) {
      const uId = String(u._id);
      const code = u.retailerId || u.customId || 'N/A';
      const uBackupRtxs = backupRtxs.filter(r => String(r.userId) === uId);
      const uProdRtxs = prodRtxs.filter(r => String(r.userId) === uId);
      const uLedgers = backupLedgers.filter(l => String(l.userId) === uId);
      const uNotifs = backupNotifs.filter(n => String(n.userId) === uId);
      const uAudits = backupAudits.filter(a => String(a.adminId) === uId || String(a.resourceId) === uId);

      totalBackupRtxs += uBackupRtxs.length;
      totalProdRtxs += uProdRtxs.length;

      const diffCount = uBackupRtxs.length - uProdRtxs.length;
      let statusStr = 'MATCH';
      if (diffCount !== 0) {
        statusStr = `${diffCount > 0 ? diffCount + ' MISSING' : Math.abs(diffCount) + ' EXTRA'}`;
        // Track missing order IDs
        uBackupRtxs.forEach(br => {
          if (!uProdRtxs.find(pr => pr.orderId === br.orderId)) {
            missingOrdersList.push({
              retailerCode: code,
              userId: uId,
              orderId: br.orderId,
              amount: br.amount || (br.grossAmountPaise ? br.grossAmountPaise/100 : 0),
              status: br.status,
              paymentMethod: br.paymentMethod,
              createdAt: br.createdAt
            });
          }
        });
      }

      console.log(`| ${code.padEnd(13)} | ${uId} | ${u.name.padEnd(15)} | ${u.phone} | ${String(uBackupRtxs.length).padStart(11)} | ${String(uProdRtxs.length).padStart(9)} | ${String(uLedgers.length).padStart(7)} | ${String(uNotifs.length).padStart(6)} | ${String(uAudits.length).padStart(6)} | ${statusStr} |`);
    }

    console.log(`\nTotal Backup Recharge Transactions: ${totalBackupRtxs}`);
    console.log(`Total Production Recharge Transactions: ${totalProdRtxs}`);
    console.log(`Total Missing Orders Count: ${missingOrdersList.length}`);

    if (missingOrdersList.length > 0) {
      console.log('\n--- COMPLETE LIST OF MISSING ORDER IDs ---');
      missingOrdersList.forEach((mo, idx) => {
        console.log(`[${idx+1}] Retailer: ${mo.retailerCode} (${mo.userId}) | Order: ${mo.orderId} | Amt: ₹${mo.amount} | Status: ${mo.status} | Method: ${mo.paymentMethod} | Created: ${mo.createdAt}`);
      });
    }

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
