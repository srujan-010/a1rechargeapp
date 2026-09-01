const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restoreRET000023CompleteHistory() {
  const prodUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXECUTING COMPLETE RESTORATION FOR RET000023 - MAHESH GANJI]');
  console.log(`Target: ${prodUri ? prodUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
  console.log('====================================================\n');

  await mongoose.connect(prodUri);
  const db = mongoose.connection.db;

  const usersCol = db.collection('users');
  const walletsCol = db.collection('wallets');
  const ledgersCol = db.collection('walletledgers');
  const rechCol = db.collection('rechargetransactions');
  const transCol = db.collection('transactions');
  const commCol = db.collection('commissionhistories');

  const maheshUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000023' }, { phone: '9421729792' }] });
  if (!maheshUser) {
    throw new Error('Retailer RET000023 (MAHESH GANJI) not found in database.');
  }

  const uId = maheshUser._id;
  console.log(`Retailer Found: ${maheshUser.name} (${maheshUser.phone}) | ID: ${uId}`);

  // 1. Restore Wallet Document
  await walletsCol.updateOne(
    { userId: uId },
    {
      $set: {
        balancePaise: 456204, // ₹4,562.04
        onHoldPaise: 0,
        currency: 'INR',
        updatedAt: new Date(),
      }
    },
    { upsert: true }
  );
  console.log('  => Wallet Balance Restored: ₹4,562.04 (456204 paise)');

  // 2. Add Money & Debit Ledger Entries
  const ledgerEntries = [
    {
      userId: uId,
      transactionType: 'CREDIT',
      amountPaise: 200000,
      previousBalancePaise: 0,
      balanceAfterPaise: 200000,
      amount: 2000.0,
      previousBalance: 0,
      balanceAfter: 2000.0,
      referenceType: 'ADD_MONEY',
      referenceId: 'RET23_ADD_1',
      description: '₹2000.00 has been added to your A1 Recharge wallet.',
      remark: 'WALLET_TOPUP',
      createdAt: new Date('2026-08-29T14:03:09.327Z'),
      updatedAt: new Date('2026-08-29T14:03:09.327Z'),
    },
    {
      userId: uId,
      transactionType: 'CREDIT',
      amountPaise: 200000,
      previousBalancePaise: 200000,
      balanceAfterPaise: 400000,
      amount: 2000.0,
      previousBalance: 2000.0,
      balanceAfter: 4000.0,
      referenceType: 'ADD_MONEY',
      referenceId: 'RET23_ADD_2',
      description: '₹2000 has been credited to your wallet.',
      remark: 'WALLET_TOPUP',
      createdAt: new Date('2026-08-30T03:32:12.311Z'),
      updatedAt: new Date('2026-08-30T03:32:12.311Z'),
    },
    {
      userId: uId,
      transactionType: 'CREDIT',
      amountPaise: 894,
      previousBalancePaise: 400000,
      balanceAfterPaise: 400894,
      amount: 8.94,
      previousBalance: 4000.0,
      balanceAfter: 4008.94,
      referenceType: 'ADD_MONEY',
      referenceId: 'RET23_ADD_3',
      description: '₹8.94 has been credited to your wallet.',
      remark: 'WALLET_TOPUP',
      createdAt: new Date('2026-08-30T03:39:58.588Z'),
      updatedAt: new Date('2026-08-30T03:39:58.588Z'),
    },
    {
      userId: uId,
      transactionType: 'DEBIT',
      amountPaise: 26610,
      previousBalancePaise: 400894,
      balanceAfterPaise: 374284,
      amount: 266.1,
      previousBalance: 4008.94,
      balanceAfter: 3742.84,
      referenceType: 'RECHARGE',
      referenceId: 'RET23_DEBIT_1',
      description: '₹266.1 has been debited for Manual Debit: debit.',
      remark: 'RECHARGE_DEBIT',
      createdAt: new Date('2026-08-30T16:00:50.796Z'),
      updatedAt: new Date('2026-08-30T16:00:50.796Z'),
    },
    {
      userId: uId,
      transactionType: 'DEBIT',
      amountPaise: 1481,
      previousBalancePaise: 374284,
      balanceAfterPaise: 372803,
      amount: 14.81,
      previousBalance: 3742.84,
      balanceAfter: 3728.03,
      referenceType: 'RECHARGE',
      referenceId: 'RET23_DEBIT_2',
      description: '₹14.81 has been debited for Manual Debit: recharge debit.',
      remark: 'RECHARGE_DEBIT',
      createdAt: new Date('2026-08-30T16:03:03.354Z'),
      updatedAt: new Date('2026-08-30T16:03:03.354Z'),
    },
    {
      userId: uId,
      transactionType: 'CREDIT',
      amountPaise: 83401,
      previousBalancePaise: 372803,
      balanceAfterPaise: 456204,
      amount: 834.01,
      previousBalance: 3728.03,
      balanceAfter: 4562.04,
      referenceType: 'ADD_MONEY',
      referenceId: 'RET23_ADD_4',
      description: '₹834.01 has been credited to your wallet.',
      remark: 'WALLET_TOPUP',
      createdAt: new Date('2026-08-30T17:30:00.197Z'),
      updatedAt: new Date('2026-08-30T17:30:00.197Z'),
    },
  ];

  for (const entry of ledgerEntries) {
    await ledgersCol.updateOne(
      { userId: uId, referenceId: entry.referenceId },
      { $set: entry },
      { upsert: true }
    );
  }
  console.log(`  => Wallet Ledgers Restored: ${ledgerEntries.length} entries (4 Add Money Credits + 2 Debits)`);

  // 3. Recharge Transaction: A1DTH1788098256836104 (Tata Sky DTH ₹280.00)
  const mainOrder = {
    orderId: 'A1DTH1788098256836104',
    userId: uId,
    providerName: 'A1Topup',
    mobileNumber: '1464685179',
    grossAmountPaise: 28000,
    commissionAmountPaise: 840, // ₹8.40 commission (3.0%)
    netPayablePaise: 27160,
    amount: 280,
    commissionAmount: 8.4,
    payableAmount: 271.6,
    operatorCode: 'TATA SKY',
    circleCode: '1',
    status: 'SUCCESS',
    paymentMethod: 'WALLET',
    walletSettlementStatus: 'SETTLED',
    completedAt: new Date('2026-08-30T13:57:44.365Z'),
    createdAt: new Date('2026-08-30T13:57:44.365Z'),
    updatedAt: new Date('2026-08-30T13:57:44.365Z'),
  };

  await rechCol.updateOne(
    { orderId: mainOrder.orderId },
    { $set: mainOrder },
    { upsert: true }
  );

  // Global Transaction Record
  await transCol.updateOne(
    { referenceId: mainOrder.orderId },
    {
      $set: {
        userId: uId,
        type: 'RECHARGE',
        amountPaise: 28000,
        payableAmountPaise: 27160,
        commissionEarnedPaise: 840,
        closingBalancePaise: 456204,
        status: 'SUCCESS',
        service: 'TATA SKY',
        referenceId: mainOrder.orderId,
        accountType: 'BUSINESS',
        paymentMethod: 'WALLET',
        completedAt: new Date('2026-08-30T13:57:44.365Z'),
        createdAt: new Date('2026-08-30T13:57:44.365Z'),
        updatedAt: new Date('2026-08-30T13:57:44.365Z'),
      }
    },
    { upsert: true }
  );

  // Commission History Record
  const rechTxDoc = await rechCol.findOne({ orderId: mainOrder.orderId });
  if (rechTxDoc) {
    await commCol.updateOne(
      { transactionId: rechTxDoc._id },
      {
        $set: {
          transactionId: rechTxDoc._id,
          userId: uId,
          operatorCode: 'TATA SKY',
          rechargeAmountPaise: 28000,
          providerCommissionAmountPaise: 1120,
          retailerCommissionAmountPaise: 840,
          companyProfitAmountPaise: 280,
          rechargeAmount: 280,
          providerCommissionPercentage: 4.0,
          providerCommissionAmount: 11.2,
          retailerCommissionPercentage: 3.0,
          retailerCommissionAmount: 8.4,
          companyProfitPercentage: 1.0,
          companyProfitAmount: 2.8,
          createdAt: new Date('2026-08-30T13:57:44.365Z'),
          updatedAt: new Date('2026-08-30T13:57:44.365Z'),
        }
      },
      { upsert: true }
    );
  }

  console.log('  => Recharge Transaction & Commission History Restored: ₹280.00 (Commission: ₹8.40)');

  console.log('\n====================================================');
  console.log('[RET000023 - MAHESH GANJI 100% RESTORATION COMPLETED]');
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreRET000023CompleteHistory().catch(err => {
    console.error('RET000023 Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { restoreRET000023CompleteHistory };
