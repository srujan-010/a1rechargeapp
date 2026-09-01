const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restoreRET000041Rajanna() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXECUTING 100% COMPLETE RESTORATION FOR RET000041 - RAJANNA MADANAYYA KONDRA]');
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

  const targetUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000041' }, { phone: '9405118660' }] });
  if (!targetUser) {
    throw new Error('Retailer RET000041 (Rajanna madanayya kondra) not found.');
  }

  const uId = targetUser._id;
  console.log(`Retailer Found: ${targetUser.name} (${targetUser.phone}) | ID: ${uId}`);

  // Clean old ledgers for RET000041
  await ledgersCol.deleteMany({ userId: uId });

  // 1. Add Money Credit: ₹300.00
  const addMoneyLedger = {
    userId: uId,
    transactionType: 'CREDIT',
    amountPaise: 30000,
    previousBalancePaise: 0,
    balanceAfterPaise: 30000,
    amount: 300.0,
    previousBalance: 0,
    balanceAfter: 300.0,
    referenceType: 'ADD_MONEY',
    referenceId: 'RET41_ADD_300',
    description: '₹300.00 has been added to your A1 Recharge wallet.',
    remark: 'WALLET_TOPUP',
    createdAt: new Date('2026-09-01T04:18:00.000Z'),
    updatedAt: new Date('2026-09-01T04:18:00.000Z'),
  };
  await ledgersCol.insertOne(addMoneyLedger);
  console.log('  => Add Money Credit Restored: +₹300.00 (30000 paise)');

  // 2. Real Recharge Transactions: 2 BSNL ₹153.00
  const rechTxns = [
    {
      orderId: 'A1R1788236372812396',
      mobileNumber: '9405118660',
      op: 'BSNL TOPUP',
      grossPaise: 15300,
      commPaise: 306, // 2.0% = ₹3.06
      netPaise: 14994, // ₹149.94
      status: 'SUCCESS',
      date: new Date('2026-09-01T04:20:19.586Z'),
    },
    {
      orderId: 'A1R1788269049460482',
      mobileNumber: '9405118660',
      op: 'BSNL TOPUP',
      grossPaise: 15300,
      commPaise: 306, // 2.0% = ₹3.06
      netPaise: 14994, // ₹149.94
      status: 'SUCCESS',
      date: new Date('2026-09-01T13:25:37.636Z'),
    },
  ];

  let currentBalPaise = 30000;

  for (let i = 0; i < rechTxns.length; i++) {
    const r = rechTxns[i];
    const grossAmt = Number((r.grossPaise / 100).toFixed(2));
    const commAmt = Number((r.commPaise / 100).toFixed(2));
    const netAmt = Number((r.netPaise / 100).toFixed(2));

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
          walletSettlementStatus: 'SETTLED',
          completedAt: r.date,
          createdAt: r.date,
          updatedAt: r.date,
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
          completedAt: r.date,
          createdAt: r.date,
          updatedAt: r.date,
        }
      },
      { upsert: true }
    );

    // Commission History
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
            providerCommissionAmountPaise: 459, // 3.0%
            retailerCommissionAmountPaise: 306, // 2.0%
            companyProfitAmountPaise: 153, // 1.0%
            rechargeAmount: grossAmt,
            providerCommissionPercentage: 3.0,
            providerCommissionAmount: 4.59,
            retailerCommissionPercentage: 2.0,
            retailerCommissionAmount: 3.06,
            companyProfitPercentage: 1.0,
            companyProfitAmount: 1.53,
            createdAt: r.date,
            updatedAt: r.date,
          }
        },
        { upsert: true }
      );
    }

    // Debit Ledger
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
      createdAt: r.date,
      updatedAt: r.date,
    });

    console.log(`  => Restored Txn [${i+1}]: ${r.orderId} | ${r.op} | Amt: ₹${grossAmt} | Comm: +₹${commAmt} | NetDebit: ₹${netAmt} | BalAfter: ₹${(currentBalPaise/100).toFixed(2)}`);
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
  console.log('[RET000041 - RAJANNA MADANAYYA KONDRA 100% RESTORATION COMPLETED]');
  console.log(`Add Money Credit       : +₹300.00`);
  console.log(`Recharge Transactions  : 2 BSNL ₹153.00 SUCCESS (Net Debits: -₹299.88)`);
  console.log(`Restored Wallet Balance: ₹${(currentBalPaise/100).toFixed(2)} (${currentBalPaise} paise)`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreRET000041Rajanna().catch(err => {
    console.error('RET000041 Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { restoreRET000041Rajanna };
