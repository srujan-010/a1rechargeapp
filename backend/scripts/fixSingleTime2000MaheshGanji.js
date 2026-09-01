const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function fixSingleTime2000MaheshGanji() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[FIXING RET000023 MAHESH GANJI - SINGLE TIME ₹2000 ADD MONEY]');
  console.log(`Database: ${prodMongoUri ? prodMongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
  console.log('====================================================\n');

  await mongoose.connect(prodMongoUri);
  const db = mongoose.connection.db;

  const usersCol = db.collection('users');
  const walletsCol = db.collection('wallets');
  const ledgersCol = db.collection('walletledgers');

  const maheshUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000023' }, { phone: '9421729792' }] });
  if (!maheshUser) {
    throw new Error('Retailer RET000023 (MAHESH GANJI) not found.');
  }

  const uId = maheshUser._id;
  console.log(`User: ${maheshUser.name} (${maheshUser.phone}) | ID: ${uId}`);

  // Delete duplicate ₹2000 topup ledger
  await ledgersCol.deleteMany({
    userId: uId,
    $or: [
      { referenceId: 'RET23_ADD_2' },
      { referenceId: 'RET23_MANUAL_1' },
      { description: /New Balance: ₹\./i },
      { referenceType: 'MANUAL' }
    ]
  });

  // Re-sync authentic ledgers
  const authenticLedgers = [
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
      amountPaise: 894,
      previousBalancePaise: 200000,
      balanceAfterPaise: 200894,
      amount: 8.94,
      previousBalance: 2000.0,
      balanceAfter: 2008.94,
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
      previousBalancePaise: 200894,
      balanceAfterPaise: 174284,
      amount: 266.1,
      previousBalance: 2008.94,
      balanceAfter: 1742.84,
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
      previousBalancePaise: 174284,
      balanceAfterPaise: 172803,
      amount: 14.81,
      previousBalance: 1742.84,
      balanceAfter: 1728.03,
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
      previousBalancePaise: 172803,
      balanceAfterPaise: 256204,
      amount: 834.01,
      previousBalance: 1728.03,
      balanceAfter: 2562.04,
      referenceType: 'ADD_MONEY',
      referenceId: 'RET23_ADD_4',
      description: '₹834.01 has been credited to your wallet.',
      remark: 'WALLET_TOPUP',
      createdAt: new Date('2026-08-30T17:30:00.197Z'),
      updatedAt: new Date('2026-08-30T17:30:00.197Z'),
    },
  ];

  for (const entry of authenticLedgers) {
    await ledgersCol.updateOne(
      { userId: uId, referenceId: entry.referenceId },
      { $set: entry },
      { upsert: true }
    );
  }

  // Update Wallet Balance to exact single-time ₹2000 calculation: ₹2,562.04 (256204 paise)
  await walletsCol.updateOne(
    { userId: uId },
    {
      $set: {
        balancePaise: 256204,
        onHoldPaise: 0,
        updatedAt: new Date(),
      }
    }
  );

  console.log('====================================================');
  console.log('[SINGLE-TIME ₹2000 TOP-UP RESTORATION FOR MAHESH GANJI COMPLETED]');
  console.log('Single Add Money ₹2000.00 credit preserved.');
  console.log('Duplicate ₹2000.00 top-up removed.');
  console.log('Restored True Wallet Balance: ₹2,562.04 (256204 paise)');
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  fixSingleTime2000MaheshGanji().catch(err => {
    console.error('Fix error:', err);
    process.exit(1);
  });
}

module.exports = { fixSingleTime2000MaheshGanji };
