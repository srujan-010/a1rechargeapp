require('dotenv').config({ path: './backend/.env' });
const mongoose = require('mongoose');

async function testGetSavings() {
  await mongoose.connect(process.env.MONGODB_URI);
  const RechargeTransaction = mongoose.model('RechargeTransaction', new mongoose.Schema({}, { strict: false }));
  
  const userId = new mongoose.Types.ObjectId('6a8c238da11c66be44e44ee2');
  const userIds = [userId, userId.toString()];

  const transactions = await RechargeTransaction.find({
    userId: { $in: userIds },
    status: { $in: ['SUCCESS', 'success', 'COMPLETED', 'completed'] },
  }).lean();

  console.log('Total SUCCESS txns found for user:', transactions.length);
  console.log('Txns:', transactions.map(t => ({
    id: t._id,
    orderId: t.orderId,
    amount: t.amount,
    commissionAmount: t.commissionAmount,
    status: t.status,
    createdAt: t.createdAt
  })));

  const now = new Date();
  const startOfCurrentMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const startOfPrevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const endOfPrevMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);

  let lifetimeSavings = 0;
  let monthlySavings = 0;
  let previousMonthSavings = 0;

  for (const txn of transactions) {
    const savings = Number(txn.commissionAmount || 0);
    lifetimeSavings += savings;

    const txnDate = new Date(txn.createdAt);
    if (txnDate >= startOfCurrentMonth) {
      monthlySavings += savings;
    } else if (txnDate >= startOfPrevMonth && txnDate <= endOfPrevMonth) {
      previousMonthSavings += savings;
    }
  }

  console.log('\n[SAVINGS DEBUG]');
  console.log('userId:', userId.toString());
  console.log('currentMonth:', `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`);
  console.log('successfulEligibleTransactions:', transactions.length);
  console.log('lifetimeSavings:', Number(lifetimeSavings.toFixed(2)));
  console.log('monthlySavings:', Number(monthlySavings.toFixed(2)));

  await mongoose.disconnect();
}

testGetSavings().catch(console.error);
