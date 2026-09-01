const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restoreRET000035Yashwant() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXECUTING 100% COMPLETE RESTORATION FOR RET000035 - YASHWANT KONDAGORLA]');
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

  const targetUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000035' }, { phone: '9404871043' }] });
  if (!targetUser) {
    throw new Error('Retailer RET000035 (Yashwant kondagorla) not found.');
  }

  const uId = targetUser._id;
  console.log(`Retailer Found: ${targetUser.name} (${targetUser.phone}) | ID: ${uId}`);

  // Clean old ledgers for RET000035
  await ledgersCol.deleteMany({ userId: uId });

  // 1. Add Money Top-ups: 2 x ₹1000.00
  const topups = [
    { amountPaise: 100000, amount: 1000.0, refId: 'RET35_ADD_1000_1', date: '2026-08-30T11:31:47.537Z', desc: '₹1000.00 has been added to your A1 Recharge wallet.' },
    { amountPaise: 100000, amount: 1000.0, refId: 'RET35_ADD_1000_2', date: '2026-08-31T04:23:22.177Z', desc: '₹1000.00 has been added to your A1 Recharge wallet.' },
  ];

  // 2. Real Recharge Transactions
  const rechTxns = [
    { orderId: 'A1DTH1788094916859319', target: '82078304613', op: 'SUN DIRECT', grossPaise: 27500, commPaise: 894, netPaise: 26606, status: 'SUCCESS', date: '2026-08-30T13:02:10.700Z' },
    { orderId: 'A1R1788099779049338', target: '9404871043', op: 'AIRTEL', grossPaise: 39900, commPaise: 399, netPaise: 39501, status: 'SUCCESS', date: '2026-08-30T14:23:20.670Z' },
    { orderId: 'A1R1788100646483388', target: '9404871043', op: 'BSNL TOPUP', grossPaise: 15300, commPaise: 306, netPaise: 14994, status: 'SUCCESS', date: '2026-08-30T14:37:38.145Z' },
    { orderId: 'A1R1788150119150424', target: '9404871043', op: 'BSNL TOPUP', grossPaise: 14700, commPaise: 294, netPaise: 14406, status: 'SUCCESS', date: '2026-08-31T04:22:11.714Z' },
    { orderId: 'A1R1788150441280364', target: '9404871043', op: 'BSNL TOPUP', grossPaise: 14700, commPaise: 294, netPaise: 14406, status: 'SUCCESS', date: '2026-08-31T04:27:44.973Z' },
    { orderId: 'A1R1788248532508410', target: '9404871043', op: 'BSNL TOPUP', grossPaise: 21900, commPaise: 438, netPaise: 21462, status: 'SUCCESS', date: '2026-09-01T07:42:25.169Z' },
    { orderId: 'A1R1788248598197995', target: '9404871043', op: 'BSNL TOPUP', grossPaise: 15300, commPaise: 306, netPaise: 14994, status: 'SUCCESS', date: '2026-09-01T07:43:30.480Z' },
    { orderId: 'A1R1788254159253689', target: '9404871043', op: 'BSNL TOPUP', grossPaise: 14700, commPaise: 0, netPaise: 14700, status: 'FAILED', date: '2026-09-01T09:16:02.691Z' },
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
          mobileNumber: r.target,
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

    // Commission History if SUCCESS
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
        description: `Recharge for ${r.target} - Order ID: ${r.orderId}`,
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
  console.log('[RET000035 - YASHWANT KONDAGORLA 100% RESTORATION COMPLETED]');
  console.log(`Add Money Credits Restored : 2 Top-ups (+₹2,000.00 total)`);
  console.log(`Recharge Transactions      : 8 Total (7 SUCCESS | 1 FAILED)`);
  console.log(`Restored Wallet Balance    : ₹${(currentBalPaise/100).toFixed(2)} (${currentBalPaise} paise)`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreRET000035Yashwant().catch(err => {
    console.error('RET000035 Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { restoreRET000035Yashwant };
