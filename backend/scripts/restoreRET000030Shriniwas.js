const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restoreRET000030Shriniwas() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXECUTING 100% COMPLETE RESTORATION FOR RET000030 - SHRINIWAS / SURESH AKULA]');
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

  const targetUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000030' }, { phone: '9420511405' }] });
  if (!targetUser) {
    throw new Error('Retailer RET000030 not found.');
  }

  const uId = targetUser._id;
  console.log(`Retailer Found: ${targetUser.name} (${targetUser.phone}) | ID: ${uId}`);

  // Clean old ledgers for RET000030
  await ledgersCol.deleteMany({ userId: uId });

  // 1. Single Add Money Credit: ₹1,000.00
  const addMoneyLedger = {
    userId: uId,
    transactionType: 'CREDIT',
    amountPaise: 100000,
    previousBalancePaise: 0,
    balanceAfterPaise: 100000,
    amount: 1000.0,
    previousBalance: 0,
    balanceAfter: 1000.0,
    referenceType: 'ADD_MONEY',
    referenceId: 'RET30_ADD_1000',
    description: '₹1000.00 has been added to your A1 Recharge wallet.',
    remark: 'WALLET_TOPUP',
    createdAt: new Date('2026-08-30T08:49:48.177Z'),
    updatedAt: new Date('2026-08-30T08:49:48.177Z'),
  };
  await ledgersCol.insertOne(addMoneyLedger);
  console.log('  => Add Money Credit Restored: +₹1,000.00 (100000 paise)');

  // 2. Real Recharge Transactions
  const rechTxns = [
    {
      orderId: 'A1R1788079665934888',
      mobileNumber: '9423121811',
      op: 'MOBILE',
      grossPaise: 1000,
      commPaise: 0,
      netPaise: 1000,
      status: 'FAILED',
      date: new Date('2026-08-30T09:18:18.554Z'),
    },
    {
      orderId: 'A1R1788081772180108',
      mobileNumber: '9420511405',
      op: 'AIRTEL',
      grossPaise: 34900,
      commPaise: 349, // 1.0% = ₹3.49
      netPaise: 34551, // ₹345.51 net debit
      status: 'SUCCESS',
      date: new Date('2026-08-30T09:23:04.153Z'),
    },
    {
      orderId: 'A1R178823938424954',
      mobileNumber: '9420511405',
      op: 'BSNL TOPUP',
      grossPaise: 1900,
      commPaise: 38, // 2.0% = ₹0.38
      netPaise: 1862, // ₹18.62 net debit
      status: 'SUCCESS',
      date: new Date('2026-09-01T05:10:05.303Z'),
    },
  ];

  let currentBalPaise = 100000;

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
  console.log('[RET000030 - SHRINIWAS 100% RESTORATION COMPLETED]');
  console.log(`Add Money Credit       : +₹1,000.00`);
  console.log(`Recharge Transactions  : 3 Total (2 SUCCESS | 1 FAILED)`);
  console.log(`Restored Wallet Balance: ₹${(currentBalPaise/100).toFixed(2)} (${currentBalPaise} paise)`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreRET000030Shriniwas().catch(err => {
    console.error('RET000030 Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { restoreRET000030Shriniwas };
