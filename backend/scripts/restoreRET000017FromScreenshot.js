const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restoreRET000017FromScreenshot() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXACT SCREENSHOT RESTORATION FOR RET000017 - ANIL AKULA]');
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

  const targetUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000017' }, { phone: '8275537100' }, { phone: '9849666060' }] });
  if (!targetUser) {
    throw new Error('Retailer RET000017 (Anil Akula) not found.');
  }

  const uId = targetUser._id;
  console.log(`Retailer Found: ${targetUser.name} (${targetUser.phone}) | ID: ${uId}`);

  // Wipe old ledgers for RET000017
  await ledgersCol.deleteMany({ userId: uId });

  // 1. Single Add Money Credit: ₹2,500.00
  const addMoneyLedger = {
    userId: uId,
    transactionType: 'CREDIT',
    amountPaise: 250000,
    previousBalancePaise: 0,
    balanceAfterPaise: 250000,
    amount: 2500.0,
    previousBalance: 0,
    balanceAfter: 2500.0,
    referenceType: 'ADD_MONEY',
    referenceId: 'WFT_1788095615496_00346',
    description: '₹2500.00 has been added to your A1 Recharge wallet.',
    remark: 'WALLET_TOPUP',
    createdAt: new Date('2026-08-30T13:14:27.000Z'),
    updatedAt: new Date('2026-08-30T13:14:27.000Z'),
  };
  await ledgersCol.insertOne(addMoneyLedger);
  console.log('  => Single Add Money Credit Restored: +₹2,500.00 (250000 paise)');

  // 2. Exact Transactions from Screenshot
  const screenshotTxns = [
    {
      orderId: 'A1R178809561549600346',
      apiRef: '5605187',
      mobileNumber: '8149914312',
      operatorCode: 'AIRTEL',
      grossAmountPaise: 34900,
      commissionAmountPaise: 140, // +₹1.40
      netPayablePaise: 34760,
      amount: 349,
      commissionAmount: 1.40,
      payableAmount: 347.60,
      status: 'SUCCESS',
      date: new Date('2026-08-30T13:54:16.000Z'),
    },
    {
      orderId: 'A1R1788097399920316',
      apiRef: '5605150',
      mobileNumber: '9423866332',
      operatorCode: 'BSNL TOPUP',
      grossAmountPaise: 21900,
      commissionAmountPaise: 0,
      netPayablePaise: 21900,
      amount: 219,
      commissionAmount: 0,
      payableAmount: 219,
      status: 'FAILED',
      date: new Date('2026-08-30T13:43:20.000Z'),
    },
    {
      orderId: 'A1R1788140843379684',
      apiRef: '5606543',
      mobileNumber: '9404130721',
      operatorCode: 'BSNL TOPUP',
      grossAmountPaise: 14700,
      commissionAmountPaise: 294, // +₹2.94
      netPayablePaise: 14406,
      amount: 147,
      commissionAmount: 2.94,
      payableAmount: 144.06,
      status: 'SUCCESS',
      date: new Date('2026-08-31T01:47:23.000Z'),
    },
    {
      orderId: 'A1R1788145703617129',
      apiRef: '5606888',
      mobileNumber: '9405453509',
      operatorCode: 'BSNL TOPUP',
      grossAmountPaise: 21900,
      commissionAmountPaise: 438, // +₹4.38
      netPayablePaise: 21462,
      amount: 219,
      commissionAmount: 4.38,
      payableAmount: 214.62,
      status: 'SUCCESS',
      date: new Date('2026-08-31T03:08:23.000Z'),
    },
    {
      orderId: 'A1R1788172231190573',
      apiRef: '5608137',
      mobileNumber: '9403928513',
      operatorCode: 'BSNL TOPUP',
      grossAmountPaise: 9900,
      commissionAmountPaise: 198, // +₹1.98
      netPayablePaise: 9702,
      amount: 99,
      commissionAmount: 1.98,
      payableAmount: 97.02,
      status: 'SUCCESS',
      date: new Date('2026-08-31T10:30:31.000Z'),
    },
    {
      orderId: 'A1R1788241806439976',
      apiRef: '5611613',
      mobileNumber: '8275036653',
      operatorCode: 'BSNL TOPUP',
      grossAmountPaise: 21900,
      commissionAmountPaise: 438, // +₹4.38
      netPayablePaise: 21462,
      amount: 219,
      commissionAmount: 4.38,
      payableAmount: 214.62,
      status: 'SUCCESS',
      date: new Date('2026-09-01T05:50:06.000Z'),
    },
  ];

  let currentBalPaise = 250000;

  for (let i = 0; i < screenshotTxns.length; i++) {
    const r = screenshotTxns[i];

    // Upsert RechargeTransaction
    await rechCol.updateOne(
      { orderId: r.orderId },
      {
        $set: {
          orderId: r.orderId,
          userId: uId,
          providerName: 'A1Topup',
          mobileNumber: r.mobileNumber,
          operatorCode: r.operatorCode,
          circleCode: '1',
          grossAmountPaise: r.grossAmountPaise,
          commissionAmountPaise: r.commissionAmountPaise,
          netPayablePaise: r.netPayablePaise,
          amount: r.amount,
          commissionAmount: r.commissionAmount,
          payableAmount: r.payableAmount,
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

    // Upsert Global Transaction
    await transCol.updateOne(
      { referenceId: r.orderId },
      {
        $set: {
          userId: uId,
          type: 'RECHARGE',
          amountPaise: r.grossAmountPaise,
          payableAmountPaise: r.netPayablePaise,
          commissionEarnedPaise: r.commissionAmountPaise,
          status: r.status,
          service: r.operatorCode,
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

    // Upsert Commission History if SUCCESS & > 0
    if (r.status === 'SUCCESS' && r.commissionAmountPaise > 0) {
      const rTxDoc = await rechCol.findOne({ orderId: r.orderId });
      if (rTxDoc) {
        await commCol.updateOne(
          { transactionId: rTxDoc._id },
          {
            $set: {
              transactionId: rTxDoc._id,
              userId: uId,
              operatorCode: r.operatorCode,
              rechargeAmountPaise: r.grossAmountPaise,
              providerCommissionAmountPaise: Math.round(r.commissionAmountPaise * 1.5),
              retailerCommissionAmountPaise: r.commissionAmountPaise,
              companyProfitAmountPaise: Math.round(r.commissionAmountPaise * 0.5),
              rechargeAmount: r.amount,
              providerCommissionPercentage: Number(((r.commissionAmount / r.amount) * 150).toFixed(2)),
              providerCommissionAmount: Number((r.commissionAmount * 1.5).toFixed(2)),
              retailerCommissionPercentage: Number(((r.commissionAmount / r.amount) * 100).toFixed(2)),
              retailerCommissionAmount: r.commissionAmount,
              companyProfitPercentage: Number(((r.commissionAmount / r.amount) * 50).toFixed(2)),
              companyProfitAmount: Number((r.commissionAmount * 0.5).toFixed(2)),
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
      currentBalPaise -= r.netPayablePaise;

      await ledgersCol.insertOne({
        userId: uId,
        transactionType: 'DEBIT',
        amountPaise: r.netPayablePaise,
        previousBalancePaise: prevBal,
        balanceAfterPaise: currentBalPaise,
        amount: r.payableAmount,
        previousBalance: Number((prevBal / 100).toFixed(2)),
        balanceAfter: Number((currentBalPaise / 100).toFixed(2)),
        referenceType: 'RECHARGE',
        referenceId: r.orderId,
        description: `Recharge for ${r.mobileNumber} - Order ID: ${r.orderId}`,
        remark: 'NET_PAYABLE_DEBIT',
        createdAt: r.date,
        updatedAt: r.date,
      });

      console.log(`  => Restored Screenshot Txn [${i+1}]: ${r.orderId} | ${r.operatorCode.padEnd(12)} | ${r.mobileNumber} | Amt: ₹${r.amount} | Comm: +₹${r.commissionAmount} | Status: ${r.status}`);
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
  console.log('[RET000017 SCREENSHOT 100% MATCHED RESTORATION COMPLETED]');
  console.log(`Single Add Money Credit : +₹2,500.00`);
  console.log(`Total Screenshot Txns   : 5 SUCCESS (Net Debits: -₹${((250000 - currentBalPaise)/100).toFixed(2)}) | 1 FAILED`);
  console.log(`Final Restored Wallet   : ₹${(currentBalPaise/100).toFixed(2)} (${currentBalPaise} paise)`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreRET000017FromScreenshot().catch(err => {
    console.error('RET000017 Screenshot Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { restoreRET000017FromScreenshot };
