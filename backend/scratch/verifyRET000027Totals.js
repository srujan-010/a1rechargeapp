const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    const db = mongoose.connection.db;

    const user = await db.collection('users').findOne({ retailerId: 'RET000027' });
    const uId = user._id;

    const rtxs = await db.collection('rechargetransactions').find({ userId: uId, status: 'SUCCESS' }).toArray();
    const wallet = await db.collection('wallets').findOne({ userId: uId });

    let totalGrossPaise = 0;
    let totalCommPaise = 0;
    let totalNetPaise = 0;

    rtxs.forEach(r => {
      totalGrossPaise += r.grossAmountPaise;
      totalCommPaise += r.commissionAmountPaise;
      totalNetPaise += r.netPayablePaise;
    });

    console.log('====================================================');
    console.log('[EXACT DATABASE AUDIT VERIFICATION FOR RET000027 - YOGESH]');
    console.log(`Total Gross Successful Recharges : ₹${(totalGrossPaise/100).toFixed(2)} (${totalGrossPaise} paise)`);
    console.log(`Total Retailer Commission Earned : ₹${(totalCommPaise/100).toFixed(2)} (${totalCommPaise} paise)`);
    console.log(`Actual Wallet Debit (Gross - Comm): ₹${(totalNetPaise/100).toFixed(2)} (${totalNetPaise} paise)`);
    console.log(`Restored Wallet Balance           : ₹${(wallet.balancePaise/100).toFixed(2)} (${wallet.balancePaise} paise)`);
    console.log('====================================================');

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
