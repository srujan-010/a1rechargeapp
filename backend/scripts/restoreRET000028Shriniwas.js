const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restoreRET000028Shriniwas() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXECUTING 100% COMPLETE RESTORATION FOR RET000028 - SHRINIWAS AKULA]');
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

  const targetUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000028' }, { phone: '7588661343' }] });
  if (!targetUser) {
    throw new Error('Retailer RET000028 (shriniwas Akula) not found.');
  }

  const uId = targetUser._id;
  console.log(`Retailer Found: ${targetUser.name} (${targetUser.phone}) | ID: ${uId}`);

  // Clean old ledgers for RET000028
  await ledgersCol.deleteMany({ userId: uId });

  // 1. Single Add Money Credit: ₹200.00
  const addMoneyLedger = {
    userId: uId,
    transactionType: 'CREDIT',
    amountPaise: 20000,
    previousBalancePaise: 0,
    balanceAfterPaise: 20000,
    amount: 200.0,
    previousBalance: 0,
    balanceAfter: 200.0,
    referenceType: 'ADD_MONEY',
    referenceId: 'RET28_ADD_200',
    description: '₹200.00 has been added to your A1 Recharge wallet.',
    remark: 'WALLET_TOPUP',
    createdAt: new Date('2026-08-30T04:51:20.978Z'),
    updatedAt: new Date('2026-08-30T04:51:20.978Z'),
  };
  await ledgersCol.insertOne(addMoneyLedger);
  console.log('  => Single Add Money Credit Restored: +₹200.00 (20000 paise)');

  // 2. Real Recharge Transactions
  const rechTxns = [
    {
      orderId: 'A1R1788065584912134',
      mobileNumber: '7588661343',
      op: 'MOBILE',
      grossPaise: 1000,
      commPaise: 0,
      netPaise: 1000,
      status: 'FAILED',
      date: new Date('2026-08-30T04:53:06.657Z'),
    },
    {
      orderId: 'A1R178806578397090',
      mobileNumber: '7588661343',
      op: 'AIRTEL',
      grossPaise: 1000,
      commPaise: 10, // 1.0% = ₹0.10
      netPaise: 990, // ₹9.90 net debit
      status: 'SUCCESS',
      date: new Date('2026-08-30T04:56:30.645Z'),
    },
  ];

  let currentBalPaise = 20000;

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
          walletSettlementStatus: r.status === 'SUCCESS' ? 'SETTLED' : 'NONE',
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
              providerCommissionAmountPaise: 15,
              retailerCommissionAmountPaise: 10,
              companyProfitAmountPaise: 5,
              rechargeAmount: grossAmt,
              providerCommissionPercentage: 1.5,
              providerCommissionAmount: 0.15,
              retailerCommissionPercentage: 1.0,
              retailerCommissionAmount: 0.10,
              companyProfitPercentage: 0.5,
              companyProfitAmount: 0.05,
              createdAt: r.date,
              updatedAt: r.date,
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
        createdAt: r.date,
        updatedAt: r.date,
      });

      console.log(`  => Restored Txn [${i+1}]: ${r.orderId} | ${r.op} | Amt: ₹${grossAmt} | Comm: +₹${commAmt} | NetDebit: ₹${netAmt} | BalAfter: ₹${(currentBalPaise/100).toFixed(2)}`);
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
  console.log('[RET000028 - SHRINIWAS AKULA 100% RESTORATION COMPLETED]');
  console.log(`Add Money Credit       : +₹200.00`);
  console.log(`Recharge Transactions  : 2 Total (1 Airtel ₹10.00 SUCCESS | 1 FAILED)`);
  console.log(`Restored Wallet Balance: ₹${(currentBalPaise/100).toFixed(2)} (${currentBalPaise} paise)`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreRET000028Shriniwas().catch(err => {
    console.error('RET000028 Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { restoreRET000028Shriniwas };
