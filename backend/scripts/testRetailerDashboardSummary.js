const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const User = require('../models/User');
const RechargeTransaction = require('../models/RechargeTransaction');

const getISTDateBounds = (daysOffset = 0) => {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = formatter.formatToParts(now);
  const partMap = {};
  parts.forEach(p => partMap[p.type] = p.value);
  
  const istNowStr = `${partMap.year}-${partMap.month}-${partMap.day}T00:00:00.000+05:30`;
  const istMidnight = new Date(istNowStr);
  
  const targetStart = new Date(istMidnight.getTime() - daysOffset * 24 * 60 * 60 * 1000);
  const targetEnd = new Date(targetStart.getTime() + 24 * 60 * 60 * 1000 - 1);
  
  return { start: targetStart, end: targetEnd };
};

async function testSummary() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('\n====================================================');
  console.log('[TEST RETAILER DASHBOARD SUMMARY AGGREGATION]');

  // Find a user with completed transactions
  const latestTx = await RechargeTransaction.findOne({ status: { $in: ['SUCCESS', 'PAYMENT_SUCCESS'] } }).sort({ createdAt: -1 }).lean();
  if (!latestTx) {
    console.log('No completed transactions found in database.');
    await mongoose.disconnect();
    return;
  }

  const userId = latestTx.userId;
  const user = await User.findById(userId).lean();
  console.log(`Testing for User: "${user ? user.name : 'Unknown'}" (_id: ${userId})`);

  const { start: todayStart, end: todayEnd } = getISTDateBounds(0);
  console.log(`Asia/Kolkata Today Start: ${todayStart.toISOString()}`);
  console.log(`Asia/Kolkata Today End:   ${todayEnd.toISOString()}`);

  const rechargeTxList = await RechargeTransaction.find({
    userId: userId,
    status: { $in: ['SUCCESS', 'PAYMENT_SUCCESS', 'completed', 'success', 'SUCCESSFUL'] },
    isTest: { $ne: true },
    orderId: { $not: /^TEST/i }
  }).lean();

  console.log(`Total successful transactions for user all-time: ${rechargeTxList.length}`);

  let todayRechargeAmountRupees = 0;
  let todayCommissionRupees = 0;
  let todayTransactionsCount = 0;

  rechargeTxList.forEach(tx => {
    const txDate = tx.completedAt || tx.createdAt;
    const isToday = txDate >= todayStart && txDate <= todayEnd;
    console.log(`- orderId: ${tx.orderId}, amount: ₹${tx.amount}, commission: ₹${tx.commissionAmount || 0}, status: ${tx.status}, date: ${txDate.toISOString()} -> ${isToday ? '[INCLUDED TODAY]' : '[EXCLUDED - NOT TODAY]'}`);

    if (isToday) {
      todayRechargeAmountRupees += (Number(tx.amount) || 0);
      todayCommissionRupees += (Number(tx.commissionAmount) || 0);
      todayTransactionsCount++;
    }
  });

  console.log('\n====================================================');
  console.log('[AGGREGATED DASHBOARD SUMMARY RESULTS]');
  console.log(`Today's Recharge: ₹${todayRechargeAmountRupees.toFixed(2)}`);
  console.log(`Commission: ₹${todayCommissionRupees.toFixed(2)}`);
  console.log(`Transactions Count: ${todayTransactionsCount}`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

testSummary().catch(console.error);
