const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function fixMaheshGanjiExact3Transactions() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXACT 3-TRANSACTION & SINGLE ₹2000 TOPUP RESTORATION FOR MAHESH GANJI]');
  console.log(`Target DB: ${prodMongoUri ? prodMongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
  console.log('====================================================\n');

  await mongoose.connect(prodMongoUri);
  const db = mongoose.connection.db;

  const usersCol = db.collection('users');
  const walletsCol = db.collection('wallets');
  const ledgersCol = db.collection('walletledgers');
  const rechCol = db.collection('rechargetransactions');
  const transCol = db.collection('transactions');
  const commCol = db.collection('commissionhistories');

  const maheshUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000023' }, { phone: '9421729792' }] });
  if (!maheshUser) {
    throw new Error('Retailer RET000023 (MAHESH GANJI) not found.');
  }

  const uId = maheshUser._id;
  console.log(`Retailer: ${maheshUser.name} (${maheshUser.phone}) | ID: ${uId}`);

  // 1. Wipe old ledgers/transactions for RET000023 to ensure clean exact state
  await ledgersCol.deleteMany({ userId: uId });

  // 2. Single Add Money Credit: ₹2,000.00
  const addMoneyLedger = {
    userId: uId,
    transactionType: 'CREDIT',
    amountPaise: 200000,
    previousBalancePaise: 0,
    balanceAfterPaise: 200000,
    amount: 2000.0,
    previousBalance: 0,
    balanceAfter: 2000.0,
    referenceType: 'ADD_MONEY',
    referenceId: 'RET23_ADD_2000',
    description: '₹2000.00 has been added to your A1 Recharge wallet.',
    remark: 'WALLET_TOPUP',
    createdAt: new Date('2026-08-29T14:03:09.327Z'),
    updatedAt: new Date('2026-08-29T14:03:09.327Z'),
  };

  await ledgersCol.insertOne(addMoneyLedger);
  console.log('  => Restored Single Add Money Credit: +₹2,000.00 (200000 paise)');

  // 3. Exact 3 Recharge Transactions
  const exact3Transactions = [
    {
      orderId: 'A1DTH1788060854555638',
      userId: uId,
      providerName: 'A1Topup',
      mobileNumber: '82193487699',
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
      completedAt: new Date('2026-08-30T03:34:17.450Z'),
      createdAt: new Date('2026-08-30T03:34:17.450Z'),
      updatedAt: new Date('2026-08-30T03:34:17.450Z'),
    },
    {
      orderId: 'A1DTH1788094427536403',
      userId: uId,
      providerName: 'A1Topup',
      mobileNumber: '9421729792',
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
      completedAt: new Date('2026-08-30T12:53:58.726Z'),
      createdAt: new Date('2026-08-30T12:53:58.726Z'),
      updatedAt: new Date('2026-08-30T12:53:58.726Z'),
    },
    {
      orderId: 'A1DTH1788098256836104',
      userId: uId,
      providerName: 'A1Topup',
      mobileNumber: '1464685179',
      grossAmountPaise: 28000,
      commissionAmountPaise: 840, // 3.0% of 28000 = 840 (₹8.40)
      netPayablePaise: 27160, // 28000 - 840 = 27160 (₹271.60)
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
    },
  ];

  let currentBalPaise = 200000;

  for (let i = 0; i < exact3Transactions.length; i++) {
    const r = exact3Transactions[i];
    await rechCol.updateOne({ orderId: r.orderId }, { $set: r }, { upsert: true });

    // Insert Global Transaction
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

    // Insert Commission History
    const rTxDoc = await rechCol.findOne({ orderId: r.orderId });
    if (rTxDoc) {
      const commRate = r.operatorCode.includes('SUN') ? 3.25 : 3.0;
      await commCol.updateOne(
        { transactionId: rTxDoc._id },
        {
          $set: {
            transactionId: rTxDoc._id,
            userId: uId,
            operatorCode: r.operatorCode,
            rechargeAmountPaise: r.grossAmountPaise,
            providerCommissionAmountPaise: Math.round(r.commissionAmountPaise * 1.3),
            retailerCommissionAmountPaise: r.commissionAmountPaise,
            companyProfitAmountPaise: Math.round(r.commissionAmountPaise * 0.3),
            rechargeAmount: r.amount,
            providerCommissionPercentage: commRate * 1.3,
            providerCommissionAmount: Number((r.commissionAmount * 1.3).toFixed(2)),
            retailerCommissionPercentage: commRate,
            retailerCommissionAmount: r.commissionAmount,
            companyProfitPercentage: commRate * 0.3,
            companyProfitAmount: Number((r.commissionAmount * 0.3).toFixed(2)),
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          }
        },
        { upsert: true }
      );
    }

    // Insert Debit Ledger
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

  // Update Wallet Document with final balance
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
  console.log('[MAHESH GANJI EXACT RESTORATION COMPLETED]');
  console.log(`Single Add Money Credit : +₹2,000.00`);
  console.log(`Total 3 Recharges Debits: -₹${((200000 - currentBalPaise)/100).toFixed(2)}`);
  console.log(`Final Restored Wallet   : ₹${(currentBalPaise/100).toFixed(2)} (${currentBalPaise} paise)`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  fixMaheshGanjiExact3Transactions().catch(err => {
    console.error('Fix error:', err);
    process.exit(1);
  });
}

module.exports = { fixMaheshGanjiExact3Transactions };
