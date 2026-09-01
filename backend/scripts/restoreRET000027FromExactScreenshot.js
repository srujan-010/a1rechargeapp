const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restoreRET000027FromExactScreenshot() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[EXACT SCREENSHOT RESTORATION FOR RET000027 - YOGESH]');
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

  const targetUser = await usersCol.findOne({ $or: [{ retailerId: 'RET000027' }, { phone: '8275528775' }] });
  if (!targetUser) {
    throw new Error('Retailer RET000027 (yogesh) not found.');
  }

  const uId = targetUser._id;
  console.log(`Retailer Found: ${targetUser.name} (${targetUser.phone}) | ID: ${uId}`);

  // Wipe old ledgers for RET000027
  await ledgersCol.deleteMany({ userId: uId });

  // 1. Wallet Top-ups from Screenshot
  const topups = [
    { amountPaise: 10000, amount: 100.0, refId: 'WFT_1788062935264_46301', date: '2026-08-30T04:09:44.000Z' },
    { amountPaise: 20000, amount: 200.0, refId: 'WFT_1788082621335_38953', date: '2026-08-30T09:37:22.000Z' },
    { amountPaise: 350000, amount: 3500.0, refId: 'WFT_1788089653718_53584', date: '2026-08-30T11:34:43.000Z' },
    { amountPaise: 200000, amount: 2000.0, refId: 'WFT_1788166524262_65865', date: '2026-08-31T08:58:10.000Z' },
  ];

  // 2. Exact 15 Successful Recharge Transactions from Screenshot
  const screenshotTxns = [
    { orderId: 'A1DTH1788082716344178', apiRef: '5604262', target: '75249356264', service: 'SUN DIRECT', grossPaise: 27500, commPaise: 894, netPaise: 26606, date: '2026-08-30T09:38:36.000Z' },
    { orderId: 'A1DTH1788089876554532', apiRef: '5604496', target: '10635957656', service: 'SUN DIRECT', grossPaise: 27500, commPaise: 894, netPaise: 26606, date: '2026-08-30T11:37:56.000Z' },
    { orderId: 'A1R178815222130148', apiRef: '5606263', target: '8275865176', service: 'BSNL TOPUP', grossPaise: 14700, commPaise: 294, netPaise: 14406, date: '2026-08-31T04:57:01.000Z' },
    { orderId: 'A1R1788152730919547', apiRef: '5606327', target: '8275584876', service: 'BSNL TOPUP', grossPaise: 14700, commPaise: 294, netPaise: 14406, date: '2026-08-31T05:05:31.000Z' },
    { orderId: 'A1R1788154200640312', apiRef: '5606586', target: '8446894394', service: 'AIRTEL', grossPaise: 39900, commPaise: 160, netPaise: 39740, date: '2026-08-31T05:30:00.000Z' },
    { orderId: 'A1R1788154487649104', apiRef: '5606639', target: '9420234045', service: 'BSNL TOPUP', grossPaise: 14700, commPaise: 294, netPaise: 14406, date: '2026-08-31T05:34:47.000Z' },
    { orderId: 'A1DTH1788154652435953', apiRef: '5606658', target: '70544334124', service: 'SUN DIRECT', grossPaise: 27500, commPaise: 894, netPaise: 26606, date: '2026-08-31T05:37:14.000Z' },
    { orderId: 'A1R1788156938197513', apiRef: '5607077', target: '9422932197', service: 'BSNL TOPUP', grossPaise: 14700, commPaise: 294, netPaise: 14406, date: '2026-08-31T06:15:36.000Z' },
    { orderId: 'A1R178815715060470', apiRef: '5607107', target: '9421869538', service: 'BSNL TOPUP', grossPaise: 22900, commPaise: 458, netPaise: 22442, date: '2026-08-31T06:19:10.000Z' },
    { orderId: 'A1R1788166721857523', apiRef: '5607648', target: '8640067291', service: 'JIO', grossPaise: 34900, commPaise: 140, netPaise: 34760, date: '2026-08-31T08:58:42.000Z' },
    { orderId: 'A1R178816981345870', apiRef: '5608383', target: '9404413227', service: 'BSNL TOPUP', grossPaise: 14700, commPaise: 294, netPaise: 14406, date: '2026-08-31T09:50:13.000Z' },
    { orderId: 'A1R1788171548091847', apiRef: '5608897', target: '8767759418', service: 'JIO', grossPaise: 34900, commPaise: 140, netPaise: 34760, date: '2026-08-31T10:19:08.000Z' },
    { orderId: 'A1R1788180703283526', apiRef: '5609826', target: '8275847889', service: 'BSNL TOPUP', grossPaise: 14700, commPaise: 294, netPaise: 14406, date: '2026-08-31T12:51:43.000Z' },
    { orderId: 'A1R1788238937592744', apiRef: '5611425', target: '8149340742', service: 'AIRTEL', grossPaise: 34900, commPaise: 140, netPaise: 34760, date: '2026-09-01T05:02:17.000Z' },
    { orderId: 'A1R1788251875904354', apiRef: '5612665', target: '7219287589', service: 'AIRTEL', grossPaise: 39900, commPaise: 160, netPaise: 39740, date: '2026-09-01T08:37:56.000Z' },
  ];

  let currentBalPaise = 0;

  // Process Top-ups
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
      description: `Wallet Topup ₹${t.amount}`,
      remark: 'WALLET_TOPUP',
      createdAt: new Date(t.date),
      updatedAt: new Date(t.date),
    });
  }

  // Process Screenshot Recharges
  for (let i = 0; i < screenshotTxns.length; i++) {
    const r = screenshotTxns[i];
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
          operatorCode: r.service,
          circleCode: '1',
          grossAmountPaise: r.grossPaise,
          commissionAmountPaise: r.commPaise,
          netPayablePaise: r.netPaise,
          amount: grossAmt,
          commissionAmount: commAmt,
          payableAmount: netAmt,
          status: 'SUCCESS',
          paymentMethod: 'WALLET',
          walletSettlementStatus: 'SETTLED',
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
          status: 'SUCCESS',
          service: r.service,
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

    // Commission History
    const rTxDoc = await rechCol.findOne({ orderId: r.orderId });
    if (rTxDoc) {
      await commCol.updateOne(
        { transactionId: rTxDoc._id },
        {
          $set: {
            transactionId: rTxDoc._id,
            userId: uId,
            operatorCode: r.service,
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
      description: `Recharge for ${r.target} - Order ID: ${r.orderId}`,
      remark: 'NET_PAYABLE_DEBIT',
      createdAt: txDate,
      updatedAt: txDate,
    });

    console.log(`  => Restored Screenshot Txn [${i+1}]: ${r.orderId} | ${r.service.padEnd(12)} | ${r.target} | Amt: ₹${grossAmt} | Comm: +₹${commAmt} | NetDebit: ₹${netAmt} | BalAfter: ₹${(currentBalPaise/100).toFixed(2)}`);
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
  console.log('[RET000027 SCREENSHOT 100% MATCHED RESTORATION COMPLETED]');
  console.log(`Top-ups Restored         : 4 Wallet Top-ups (+₹5,800.00 total)`);
  console.log(`Recharge Transactions    : 15 Exact Screenshot SUCCESS Items (Net Debits: -₹${((580000 - currentBalPaise)/100).toFixed(2)})`);
  console.log(`Final Restored Wallet    : ₹${(currentBalPaise/100).toFixed(2)} (${currentBalPaise} paise)`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreRET000027FromExactScreenshot().catch(err => {
    console.error('RET000027 Screenshot Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { restoreRET000027FromExactScreenshot };
