const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restoreRET000042Nageshwar() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXECUTING 100% COMPLETE RESTORATION FOR RET000042 - NAGESHWAR SATYANARAYANA NERLAWAR]');
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

  const targetUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000042' }, { phone: '9573916413' }] });
  if (!targetUser) {
    throw new Error('Retailer RET000042 (Nageshwar Satyanarayana nerlawar) not found.');
  }

  const uId = targetUser._id;
  console.log(`Retailer Found: ${targetUser.name} (${targetUser.phone}) | ID: ${uId}`);

  // Clean old ledgers for RET000042
  await ledgersCol.deleteMany({ userId: uId });

  // 1. Single Add Money Credit: ₹500.00
  const addMoneyLedger = {
    userId: uId,
    transactionType: 'CREDIT',
    amountPaise: 50000,
    previousBalancePaise: 0,
    balanceAfterPaise: 50000,
    amount: 500.0,
    previousBalance: 0,
    balanceAfter: 500.0,
    referenceType: 'ADD_MONEY',
    referenceId: 'RET42_ADD_500',
    description: '₹500.00 has been added to your A1 Recharge wallet.',
    remark: 'WALLET_TOPUP',
    createdAt: new Date('2026-09-01T02:51:11.828Z'),
    updatedAt: new Date('2026-09-01T02:51:11.828Z'),
  };
  await ledgersCol.insertOne(addMoneyLedger);
  console.log('  => Single Add Money Credit Restored: +₹500.00 (50000 paise)');

  // 2. Real Recharge Transaction: Airtel ₹349.00
  const r = {
    orderId: 'A1R1788231162565130',
    mobileNumber: '9573916413',
    op: 'AIRTEL',
    grossPaise: 34900,
    commPaise: 349, // 1.0% = ₹3.49
    netPaise: 34551, // ₹345.51 net debit
    status: 'SUCCESS',
    date: new Date('2026-09-01T02:52:55.254Z'),
  };

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
        amount: 349,
        commissionAmount: 3.49,
        payableAmount: 345.51,
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
          providerCommissionAmountPaise: 523, // 1.5%
          retailerCommissionAmountPaise: 349, // 1.0%
          companyProfitAmountPaise: 174, // 0.5%
          rechargeAmount: 349,
          providerCommissionPercentage: 1.5,
          providerCommissionAmount: 5.23,
          retailerCommissionPercentage: 1.0,
          retailerCommissionAmount: 3.49,
          companyProfitPercentage: 0.5,
          companyProfitAmount: 1.74,
          createdAt: r.date,
          updatedAt: r.date,
        }
      },
      { upsert: true }
    );
  }

  // Debit Ledger
  const currentBalPaise = 50000 - r.netPaise; // 15449 paise (₹154.49)
  await ledgersCol.insertOne({
    userId: uId,
    transactionType: 'DEBIT',
    amountPaise: r.netPaise,
    previousBalancePaise: 50000,
    balanceAfterPaise: currentBalPaise,
    amount: 345.51,
    previousBalance: 500.0,
    balanceAfter: 154.49,
    referenceType: 'RECHARGE',
    referenceId: r.orderId,
    description: `Recharge for ${r.mobileNumber} - Order ID: ${r.orderId}`,
    remark: 'NET_PAYABLE_DEBIT',
    createdAt: r.date,
    updatedAt: r.date,
  });

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
  console.log('[RET000042 - NAGESHWAR SATYANARAYANA NERLAWAR 100% RESTORATION COMPLETED]');
  console.log(`Single Add Money Credit : +₹500.00`);
  console.log(`Recharge Transaction    : Airtel ₹349.00 (Comm: ₹3.49 | Net Debit: ₹345.51)`);
  console.log(`Restored Wallet Balance : ₹154.49 (15449 paise)`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreRET000042Nageshwar().catch(err => {
    console.error('RET000042 Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { restoreRET000042Nageshwar };
