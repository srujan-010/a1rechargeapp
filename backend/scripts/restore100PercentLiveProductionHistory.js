const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restore100PercentLiveProductionHistory() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXECUTING 100% TRANSACTION RESTORATION TO PRODUCTION ATLAS]');
  console.log(`Database: ${prodMongoUri ? prodMongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
  console.log('====================================================\n');

  await mongoose.connect(prodMongoUri);
  const db = mongoose.connection.db;

  const notifsCol = db.collection('notifications');
  const rechCol = db.collection('rechargetransactions');
  const transCol = db.collection('transactions');
  const ledgersCol = db.collection('walletledgers');
  const usersCol = db.collection('users');

  const users = await usersCol.find({}).toArray();
  const userMap = new Map(users.map(u => [String(u._id), u]));

  const existingRechTxns = await rechCol.find({}).toArray();
  const existingOrderIds = new Set(existingRechTxns.map(r => r.orderId));

  const notifs = await notifsCol.find({}).sort({ createdAt: 1 }).toArray();

  let restoredRechCount = 0;
  let restoredGlobalCount = 0;

  for (const n of notifs) {
    const orderId = n.relatedOrderId || (n.data ? n.data.orderId : null);
    if (!orderId || existingOrderIds.has(orderId)) continue;

    const u = userMap.get(String(n.userId));
    if (!u) continue; // Exclude test/unknown user notifications

    const title = n.title || '';
    const msg = n.message || '';
    const createdAt = n.createdAt || new Date();

    const matchAmt = msg.match(/₹\s*([\d.]+)/) || (n.data && n.data.amount ? [null, n.data.amount] : null);
    const amtRupees = matchAmt ? parseFloat(matchAmt[1]) : 0;
    const amtPaise = Math.round(amtRupees * 100);

    if (amtPaise <= 0) continue;

    const operatorMatch = msg.match(/(Airtel|BSNL|BSNL TOPUP|Jio|VI|SUN DIRECT|TATA SKY|DISH TV|VIDEOCON)/i) || (n.data && n.data.operator ? [null, n.data.operator] : null);
    const operatorStr = operatorMatch ? operatorMatch[1] : 'MOBILE';

    const phoneMatch = msg.match(/\b\d{10}\b/);
    const mobileNumber = phoneMatch ? phoneMatch[0] : u.phone;

    let status = 'SUCCESS';
    if (title.includes('Failed') || msg.includes('failed')) status = 'FAILED';
    if (title.includes('Pending') || msg.includes('pending')) status = 'PENDING';

    const newRechTx = {
      orderId,
      userId: u._id,
      providerName: 'A1Topup',
      mobileNumber,
      grossAmountPaise: amtPaise,
      commissionAmountPaise: 0,
      netPayablePaise: amtPaise,
      amount: amtRupees,
      commissionAmount: 0,
      payableAmount: amtRupees,
      operatorCode: operatorStr.toUpperCase(),
      circleCode: '1',
      status,
      paymentMethod: 'WALLET',
      walletSettlementStatus: status === 'SUCCESS' ? 'SETTLED' : (status === 'FAILED' ? 'RELEASED' : 'PENDING'),
      completedAt: createdAt,
      createdAt,
      updatedAt: createdAt,
    };

    await rechCol.insertOne(newRechTx);
    restoredRechCount++;

    // Insert into global transactions collection
    const newGlobalTx = {
      userId: u._id,
      type: 'RECHARGE',
      amountPaise: amtPaise,
      payableAmountPaise: amtPaise,
      commissionEarnedPaise: 0,
      closingBalancePaise: 0,
      status,
      service: operatorStr,
      referenceId: orderId,
      accountType: u.accountType || 'BUSINESS',
      paymentMethod: 'WALLET',
      completedAt: createdAt,
      createdAt,
      updatedAt: createdAt,
    };

    await transCol.insertOne(newGlobalTx);
    restoredGlobalCount++;

    existingOrderIds.add(orderId);
  }

  console.log('\n====================================================');
  console.log(`[RESTORATION COMPLETED] Restored ${restoredRechCount} recharge transactions and ${restoredGlobalCount} global transactions!`);
  console.log('====================================================\n');

  // Verify RET000042, RET000041, RET000036
  console.log('--- VERIFICATION FOR RET000042, RET000041, RET000036 ---');
  for (const code of ['RET000042', 'RET000041', 'RET000036', 'RET000035']) {
    const targetU = users.find(u => u.retailerId === code || u.customId === code);
    if (targetU) {
      const uRtxs = await rechCol.find({ userId: targetU._id }).toArray();
      const uGlobal = await transCol.find({ userId: targetU._id }).toArray();
      console.log(`Retailer ${code} (${targetU.name} - ${targetU.phone}):`);
      console.log(`  Recharge Transactions Count: ${uRtxs.length} | Global Transactions Count: ${uGlobal.length}`);
      uRtxs.forEach((r, i) => console.log(`    [${i+1}] ${r.orderId} | ₹${r.amount} | ${r.operatorCode} | ${r.status} | ${r.createdAt ? new Date(r.createdAt).toISOString() : 'N/A'}`));
    }
  }

  await mongoose.disconnect();
}

if (require.main === module) {
  restore100PercentLiveProductionHistory().catch(err => {
    console.error('Live Production Restoration Error:', err);
    process.exit(1);
  });
}

module.exports = { restore100PercentLiveProductionHistory };
