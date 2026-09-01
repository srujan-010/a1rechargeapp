const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

(() => {
  const archivePath = path.join(__dirname, '../a1recharge_pre_restore_backup_20260901.gz');
  const archiveBuffer = fs.readFileSync(archivePath);
  const archiveData = JSON.parse(zlib.gunzipSync(archiveBuffer).toString('utf-8'));

  const users = archiveData.collections['users'] || [];
  const wallets = archiveData.collections['wallets'] || [];
  const ledgers = archiveData.collections['walletledgers'] || [];
  const rtxs = archiveData.collections['rechargetransactions'] || [];
  const notifs = archiveData.collections['notifications'] || [];

  const u = users.find(user => user.phone === '9421729792' || user.retailerId === 'RET000023');
  if (!u) {
    console.error('User 9421729792 not found');
    return;
  }

  const uId = String(u._id);
  console.log('====================================================');
  console.log(`[ORIGINAL UNTOUCHED BACKUP DATA FOR RET000023 - MAHESH GANJI]`);
  console.log(`User ID: ${uId} | Phone: ${u.phone} | Name: ${u.name}`);
  console.log('====================================================\n');

  const w = wallets.find(w => String(w.userId) === uId);
  console.log('--- ORIGINAL BACKUP WALLET ---');
  console.log(JSON.stringify(w, null, 2));

  const uLedgers = ledgers.filter(l => String(l.userId) === uId);
  console.log(`\n--- ORIGINAL BACKUP WALLET LEDGERS (${uLedgers.length}) ---`);
  uLedgers.forEach((l, i) => console.log(`  [${i+1}] ${l.createdAt} | Type: ${l.transactionType} | Amt: ₹${l.amount || (l.amountPaise/100)} (${l.amountPaise}p) | Ref: ${l.referenceType} | Desc: ${l.description}`));

  const uRtxs = rtxs.filter(r => String(r.userId) === uId);
  console.log(`\n--- ORIGINAL BACKUP RECHARGE TRANSACTIONS (${uRtxs.length}) ---`);
  uRtxs.forEach((r, i) => console.log(`  [${i+1}] ${r.createdAt} | orderId: ${r.orderId} | Amt: ₹${r.amount} | Comm: ₹${r.commissionAmount} | Status: ${r.status}`));

})();
