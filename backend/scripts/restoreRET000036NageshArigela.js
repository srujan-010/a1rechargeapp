const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restoreRET000036NageshArigela() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXECUTING 100% COMPLETE RESTORATION FOR RET000036 - NAGESH L ARIGELA]');
  console.log(`Database: ${prodMongoUri ? prodMongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
  console.log('====================================================\n');

  await mongoose.connect(prodMongoUri);
  const db = mongoose.connection.db;

  const usersCol = db.collection('users');
  const walletsCol = db.collection('wallets');
  const ledgersCol = db.collection('walletledgers');
  const rechCol = db.collection('rechargetransactions');
  const transCol = db.collection('transactions');
  const commCol = db.collection('commissionhistories');

  const targetUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000036' }, { phone: '9422712600' }] });
  if (!targetUser) {
    throw new Error('Retailer RET000036 (Nagesh L Arigela) not found.');
  }

  const uId = targetUser._id;
  console.log(`Retailer Found: ${targetUser.name} (${targetUser.phone}) | ID: ${uId}`);

  // Wipe old ledgers for RET000036
  await ledgersCol.deleteMany({ userId: uId });

  // 1. Add Money Top-ups
  const topups = [
    { amountPaise: 100000, amount: 1000.0, refId: 'RET36_ADD_1000', date: '2026-08-30T14:24:16.939Z', desc: '₹1000.00 has been added to your A1 Recharge wallet.' },
    { amountPaise: 54800, amount: 548.0, refId: 'RET36_ADD_548', date: '2026-09-01T08:40:55.469Z', desc: '₹548.00 has been credited to your wallet.' },
  ];

  // 2. Real Recharge Transactions
  const rechTxns = [
    { orderId: 'A1DTH1788099940358412', mobileNumber: '9422712600', op: 'SUN DIRECT', grossPaise: 27500, commPaise: 894, netPaise: 26606, status: 'SUCCESS', date: '2026-08-30T14:25:43.187Z' },
    { orderId: 'A1R1788244853621610', mobileNumber: '9422712600', op: 'AIRTEL', grossPaise: 34900, commPaise: 349, netPaise: 34551, status: 'SUCCESS', date: '2026-09-01T06:41:10.503Z' },
    { orderId: 'A1R178824979986423', mobileNumber: '9422712600', op: 'AIRTEL', grossPaise: 34900, commPaise: 349, netPaise: 34551, status: 'SUCCESS', date: '2026-09-01T08:04:43.263Z' },
    { orderId: 'A1R1788251460770252', mobileNumber: '9422712600', op: 'MOBILE', grossPaise: 29900, commPaise: 0, netPaise: 29900, status: 'FAILED', date: '2026-09-01T08:31:47.090Z' },
    { orderId: 'A1R17882529182312', mobileNumber: '9422712600', op: 'JIO', grossPaise: 29900, commPaise: 239, netPaise: 29661, status: 'SUCCESS', date: '2026-09-01T08:57:56.944Z' },
    { orderId: 'A1R1788254468482166', mobileNumber: '9422712600', op: 'AIRTEL', grossPaise: 19900, commPaise: 0, netPaise: 19900, status: 'FAILED', date: '2026-09-01T09:21:17.506Z' },
  ];

  let currentBalPaise = 0;

  // Process Add Money Ledgers
  for (const t of topups) {
    const prevBal = currentBalPaise;
    currentBalPaise += t.amountPaise;
    await ledgersCol.insertOne({
      userId: uId,
      transactionType: 'CREDIT',
      amountPaise: t.amountPaise,
      previousBalancePaise: prevBal,
      balanceAfterPaise: currentBalPaise,
      amount: t.amount,
      previousBalance: Number((prevBal / 100).toFixed(2)),
      balanceAfter: Number((currentBalPaise / 100).toFixed(2)),
      referenceType: 'ADD_MONEY',
      referenceId: t.refId,
      description: t.desc,
      remark: 'WALLET_TOPUP',
      createdAt: new Date(t.date),
      updatedAt: new Date(t.date),
    });
  }

  // Process Recharges
  for (let i = 0; i < rechTxns.length; i++) {
    const r = rechTxns[i];
    const grossAmt = Number((r.grossPaise / 100).toFixed(2));
    const commAmt = Number((r.commPaise / 100).toFixed(2));
    const netAmt = Number((r.netPaise / 100).toFixed(2));
    const txDate = new Date(r.date);

    await rechCol.updateOne(
      { orderId: r.orderId },
      {
        $set: {
          orderId: r.orderId,
          userId: uId,
          providerName: 'A1Topup',
          mobileNumber: r.mobileNumber,
          operatorCode: r.op,
          circleCode: '1',
          grossAmountPaise: r.grossPaise,
          commissionAmountPaise: r.commPaise,
          netPayablePaise: r.netPaise,
          amount: grossAmt,
          commissionAmount: commAmt,
          payableAmount: netAmt,
          status: r.status,
          paymentMethod: 'WALLET',
          walletSettlementStatus: r.status === 'SUCCESS' ? 'SETTLED' : 'NONE',
          completedAt: txDate,
          createdAt: txDate,
          updatedAt: txDate,
        }
      },
      { upsert: true }
    );

    // Global Transaction
    await transCol.updateOne(
      { referenceId: r.orderId },
      {
        $set: {
          userId: uId,
          type: 'RECHARGE',
          amountPaise: r.grossPaise,
          payableAmountPaise: r.netPaise,
          commissionEarnedPaise: r.commPaise,
          status: r.status,
          service: r.op,
          referenceId: r.orderId,
          accountType: 'BUSINESS',
          paymentMethod: 'WALLET',
          completedAt: txDate,
          createdAt: txDate,
          updatedAt: txDate,
        }
      },
      { upsert: true }
    );

    // Commission History if SUCCESS & > 0
    if (r.status === 'SUCCESS' && r.commPaise > 0) {
      const rTxDoc = await rechCol.findOne({ orderId: r.orderId });
      if (rTxDoc) {
        await commCol.updateOne(
          { transactionId: rTxDoc._id },
          {
            $set: {
              transactionId: rTxDoc._id,
              userId: uId,
              operatorCode: r.op,
              rechargeAmountPaise: r.grossPaise,
              providerCommissionAmountPaise: Math.round(r.commPaise * 1.5),
              retailerCommissionAmountPaise: r.commPaise,
              companyProfitAmountPaise: Math.round(r.commPaise * 0.5),
              rechargeAmount: grossAmt,
              providerCommissionPercentage: Number(((commAmt / grossAmt) * 150).toFixed(2)),
              providerCommissionAmount: Number((commAmt * 1.5).toFixed(2)),
              retailerCommissionPercentage: Number(((commAmt / grossAmt) * 100).toFixed(2)),
              retailerCommissionAmount: commAmt,
              companyProfitPercentage: Number(((commAmt / grossAmt) * 50).toFixed(2)),
              companyProfitAmount: Number((commAmt * 0.5).toFixed(2)),
              createdAt: txDate,
              updatedAt: txDate,
            }
          },
          { upsert: true }
        );
      }
    }

    // Debit Ledger if SUCCESS
    if (r.status === 'SUCCESS') {
      const prevBal = currentBalPaise;
      currentBalPaise -= r.netPaise;

      await ledgersCol.insertOne({
        userId: uId,
        transactionType: 'DEBIT',
        amountPaise: r.netPaise,
        previousBalancePaise: prevBal,
        balanceAfterPaise: currentBalPaise,
        amount: netAmt,
        previousBalance: Number((prevBal / 100).toFixed(2)),
        balanceAfter: Number((currentBalPaise / 100).toFixed(2)),
        referenceType: 'RECHARGE',
        referenceId: r.orderId,
        description: `Recharge for ${r.mobileNumber} - Order ID: ${r.orderId}`,
        remark: 'NET_PAYABLE_DEBIT',
        createdAt: txDate,
        updatedAt: txDate,
      });

      console.log(`  => Restored Txn [${i+1}]: ${r.orderId} | ${r.op.padEnd(12)} | Amt: ₹${grossAmt} | Comm: +₹${commAmt} | NetDebit: ₹${netAmt} | BalAfter: ₹${(currentBalPaise/100).toFixed(2)}`);
    }
  }

  // Update Wallet Document
  await walletsCol.updateOne(
    { userId: uId },
    {
      $set: {
        balancePaise: currentBalPaise,
        onHoldPaise: 0,
        currency: 'INR',
        updatedAt: new Date(),
      }
    },
    { upsert: true }
  );

  console.log('\n====================================================');
  console.log('[RET000036 - NAGESH L ARIGELA 100% RESTORATION COMPLETED]');
  console.log(`Add Money Credits Restored : 2 Top-ups (+₹1,000.00 & +₹548.00)`);
  console.log(`Recharge Transactions      : 6 Total (4 SUCCESS | 2 FAILED)`);
  console.log(`Restored Wallet Balance    : ₹${(currentBalPaise/100).toFixed(2)} (${currentBalPaise} paise)`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreRET000036NageshArigela().catch(err => {
    console.error('RET000036 Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { restoreRET000036NageshArigela };
