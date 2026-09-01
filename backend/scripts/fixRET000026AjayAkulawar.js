const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function fixRET000026AjayAkulawar() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXACT SINGLE ₹5000 TOPUP & REAL TRANSACTIONS RESTORATION FOR RET000026]');
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

  const ajayUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000026' }, { phone: '9405999503' }] });
  if (!ajayUser) {
    throw new Error('Retailer RET000026 (Ajay Akulawar) not found.');
  }

  const uId = ajayUser._id;
  console.log(`Retailer: ${ajayUser.name} (${ajayUser.phone}) | ID: ${uId}`);

  // Wipe old ledgers for RET000026 to ensure clean exact state
  await ledgersCol.deleteMany({ userId: uId });

  // 1. Single Add Money Credit: ₹5,000.00
  const addMoneyLedger = {
    userId: uId,
    transactionType: 'CREDIT',
    amountPaise: 500000,
    previousBalancePaise: 0,
    balanceAfterPaise: 500000,
    amount: 5000.0,
    previousBalance: 0,
    balanceAfter: 5000.0,
    referenceType: 'ADD_MONEY',
    referenceId: 'RET26_ADD_5000',
    description: '₹5000.00 has been added to your A1 Recharge wallet.',
    remark: 'WALLET_TOPUP',
    createdAt: new Date('2026-08-30T03:47:09.740Z'),
    updatedAt: new Date('2026-08-30T03:47:09.740Z'),
  };

  await ledgersCol.insertOne(addMoneyLedger);
  console.log('  => Restored Single Add Money Credit: +₹5,000.00 (500000 paise)');

  // 2. Real Recharge Transactions
  const realTransactions = [
    {
      orderId: 'A1R1788069512599611',
      userId: uId,
      providerName: 'A1Topup',
      mobileNumber: '9405999503',
      grossAmountPaise: 14700,
      commissionAmountPaise: 294, // 2.0% of 14700 = 294 (₹2.94)
      netPayablePaise: 14406, // 14700 - 294 = 14406 (₹144.06)
      amount: 147,
      commissionAmount: 2.94,
      payableAmount: 144.06,
      operatorCode: 'BSNL',
      circleCode: '1',
      status: 'SUCCESS',
      paymentMethod: 'WALLET',
      walletSettlementStatus: 'SETTLED',
      completedAt: new Date('2026-08-30T05:58:44.782Z'),
      createdAt: new Date('2026-08-30T05:58:44.782Z'),
      updatedAt: new Date('2026-08-30T05:58:44.782Z'),
    },
    {
      orderId: 'A1DTH1788089951133972',
      userId: uId,
      providerName: 'A1Topup',
      mobileNumber: '70633604270',
      grossAmountPaise: 27500,
      commissionAmountPaise: 894, // 3.25% of 27500 = 894 (₹8.94)
      netPayablePaise: 26606, // 27500 - 894 = 26606 (₹266.06)
      amount: 275,
      commissionAmount: 8.94,
      payableAmount: 266.06,
      operatorCode: 'SUN DIRECT',
      circleCode: '1',
      status: 'SUCCESS',
      paymentMethod: 'WALLET',
      walletSettlementStatus: 'SETTLED',
      completedAt: new Date('2026-08-30T11:39:18.503Z'),
      createdAt: new Date('2026-08-30T11:39:18.503Z'),
      updatedAt: new Date('2026-08-30T11:39:18.503Z'),
    },
    {
      orderId: 'A1R1788150738792210',
      userId: uId,
      providerName: 'A1Topup',
      mobileNumber: '9405999503',
      grossAmountPaise: 29900,
      commissionAmountPaise: 239, // 0.8% of 29900 = 239 (₹2.39)
      netPayablePaise: 29661, // 29900 - 239 = 29661 (₹296.61)
      amount: 299,
      commissionAmount: 2.39,
      payableAmount: 296.61,
      operatorCode: 'JIO',
      circleCode: '1',
      status: 'SUCCESS',
      paymentMethod: 'WALLET',
      walletSettlementStatus: 'SETTLED',
      completedAt: new Date('2026-08-31T04:32:39.801Z'),
      createdAt: new Date('2026-08-31T04:32:39.801Z'),
      updatedAt: new Date('2026-08-31T04:32:39.801Z'),
    },
    {
      orderId: 'A1R1788179865429880',
      userId: uId,
      providerName: 'A1Topup',
      mobileNumber: '9405999503',
      grossAmountPaise: 29900,
      commissionAmountPaise: 239, // 0.8% of 29900 = 239 (₹2.39)
      netPayablePaise: 29661, // 29900 - 239 = 29661 (₹296.61)
      amount: 299,
      commissionAmount: 2.39,
      payableAmount: 296.61,
      operatorCode: 'JIO',
      circleCode: '1',
      status: 'SUCCESS',
      paymentMethod: 'WALLET',
      walletSettlementStatus: 'SETTLED',
      completedAt: new Date('2026-08-31T12:38:00.416Z'),
      createdAt: new Date('2026-08-31T12:38:00.416Z'),
      updatedAt: new Date('2026-08-31T12:38:00.416Z'),
    },
  ];

  let currentBalPaise = 500000;

  for (let i = 0; i < realTransactions.length; i++) {
    const r = realTransactions[i];
    await rechCol.updateOne({ orderId: r.orderId }, { $set: r }, { upsert: true });

    // Global Transaction
    await transCol.updateOne(
      { referenceId: r.orderId },
      {
        $set: {
          userId: uId,
          type: 'RECHARGE',
          amountPaise: r.grossAmountPaise,
          payableAmountPaise: r.netPayablePaise,
          commissionEarnedPaise: r.commissionAmountPaise,
          status: 'SUCCESS',
          service: r.operatorCode,
          referenceId: r.orderId,
          accountType: 'BUSINESS',
          paymentMethod: 'WALLET',
          completedAt: r.completedAt,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        }
      },
      { upsert: true }
    );

    // Commission History
    const rTxDoc = await rechCol.findOne({ orderId: r.orderId });
    if (rTxDoc) {
      const commRate = r.operatorCode === 'BSNL' ? 2.0 : (r.operatorCode === 'SUN DIRECT' ? 3.25 : 0.8);
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
            providerCommissionPercentage: commRate * 1.5,
            providerCommissionAmount: Number((r.commissionAmount * 1.5).toFixed(2)),
            retailerCommissionPercentage: commRate,
            retailerCommissionAmount: r.commissionAmount,
            companyProfitPercentage: commRate * 0.5,
            companyProfitAmount: Number((r.commissionAmount * 0.5).toFixed(2)),
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          }
        },
        { upsert: true }
      );
    }

    // Debit Ledger
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
      referenceId: rTxDoc ? rTxDoc._id : r.orderId,
      description: `Recharge for ${r.mobileNumber} - Order ID: ${r.orderId}`,
      remark: 'NET_PAYABLE_DEBIT',
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    });

    console.log(`  => Restored Txn [${i+1}]: ${r.orderId} | ${r.operatorCode} ₹${r.amount} | Comm: ₹${r.commissionAmount} | NetDebit: ₹${r.payableAmount} | BalAfter: ₹${(currentBalPaise/100).toFixed(2)}`);
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
  console.log('[RET000026 - AJAY AKULAWAR EXACT RESTORATION COMPLETED]');
  console.log(`Single Add Money Credit : +₹5,000.00`);
  console.log(`Total 4 Recharges Debits: -₹${((500000 - currentBalPaise)/100).toFixed(2)}`);
  console.log(`Final Restored Wallet   : ₹${(currentBalPaise/100).toFixed(2)} (${currentBalPaise} paise)`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  fixRET000026AjayAkulawar().catch(err => {
    console.error('RET000026 Fix Error:', err);
    process.exit(1);
  });
}

module.exports = { fixRET000026AjayAkulawar };
