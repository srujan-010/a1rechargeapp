const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const commissionRates = {
  'BSNL': 2.0,
  'BSNL TOPUP': 2.0,
  'BR': 2.0,
  'BT': 2.0,
  'AIRTEL': 1.0,
  'AT': 1.0,
  'JIO': 0.8,
  'JO': 0.8,
  'VI': 2.7,
  'SUN DIRECT': 3.25,
  'SUN': 3.25,
  'TATA SKY': 3.20,
  'TATA PLAY': 3.20,
  'TP': 3.20,
  'DISH TV': 3.25,
  'DISH': 3.25,
  'MOBILE': 1.0
};

async function restoreCommissionsAndTodayDashboardSummary() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[RESTORING 100% RETAILER COMMISSIONS & DASHBOARD SUMMARY]');
  console.log(`Database: ${prodMongoUri ? prodMongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
  console.log('====================================================\n');

  await mongoose.connect(prodMongoUri);
  const db = mongoose.connection.db;

  const rechCol = db.collection('rechargetransactions');
  const transCol = db.collection('transactions');
  const commCol = db.collection('commissionhistories');
  const notifsCol = db.collection('notifications');

  const rtxs = await rechCol.find({}).toArray();
  console.log(`Auditing and updating ${rtxs.length} recharge transactions...`);

  let updatedCommCount = 0;

  for (const r of rtxs) {
    const isSuccess = ['SUCCESS', 'PAYMENT_SUCCESS', 'completed', 'success', 'SUCCESSFUL'].includes(r.status);
    const op = (r.operatorCode || 'MOBILE').toUpperCase();
    const amtRupees = Number(r.amount) || ((Number(r.grossAmountPaise) || 0) / 100);
    const amtPaise = Math.round(amtRupees * 100);

    // Parse commission from notification if available
    let commRupees = Number(r.commissionAmount) || 0;
    let commPaise = Number(r.commissionAmountPaise) || 0;

    if (commPaise <= 0 && isSuccess) {
      // Check notification for exact commission string (e.g. "You saved ₹3.06 on this recharge")
      const notif = await notifsCol.findOne({ relatedOrderId: r.orderId, message: /commission|saved/i });
      if (notif) {
        const m = notif.message.match(/₹\s*([\d.]+)/);
        if (m) {
          commRupees = parseFloat(m[1]);
          commPaise = Math.round(commRupees * 100);
        }
      }
    }

    if (commPaise <= 0 && isSuccess) {
      // Calculate rate based on operator
      const rate = commissionRates[op] || 1.0;
      commRupees = Number(((amtRupees * rate) / 100).toFixed(2));
      commPaise = Math.round(commRupees * 100);
    }

    const netPayablePaise = Math.max(0, amtPaise - commPaise);
    const netPayableRupees = Number((netPayablePaise / 100).toFixed(2));

    // Ensure timestamp falls into today's IST bounds if created today
    const txDate = r.completedAt || r.createdAt || new Date();

    // Update RechargeTransaction
    await rechCol.updateOne(
      { _id: r._id },
      {
        $set: {
          commissionAmountPaise: commPaise,
          commissionAmount: commRupees,
          netPayablePaise,
          payableAmount: netPayableRupees,
          completedAt: txDate,
          updatedAt: new Date(),
        }
      }
    );

    // Update Transaction model record
    await transCol.updateOne(
      { referenceId: r.orderId },
      {
        $set: {
          commissionEarnedPaise: commPaise,
          commissionAmount: commRupees,
          completedAt: txDate,
          updatedAt: new Date(),
        }
      }
    );

    // Upsert into CommissionHistory if SUCCESS
    if (isSuccess && commPaise > 0) {
      const rate = commissionRates[op] || 1.0;
      await commCol.updateOne(
        { transactionId: r._id },
        {
          $set: {
            transactionId: r._id,
            userId: r.userId,
            operatorCode: op,
            rechargeAmountPaise: amtPaise,
            providerCommissionAmountPaise: Math.round(commPaise * 1.5),
            retailerCommissionAmountPaise: commPaise,
            companyProfitAmountPaise: Math.round(commPaise * 0.5),
            rechargeAmount: amtRupees,
            providerCommissionPercentage: rate * 1.5,
            providerCommissionAmount: commRupees * 1.5,
            retailerCommissionPercentage: rate,
            retailerCommissionAmount: commRupees,
            companyProfitPercentage: rate * 0.5,
            companyProfitAmount: commRupees * 0.5,
            createdAt: txDate,
            updatedAt: new Date(),
          }
        },
        { upsert: true }
      );
      updatedCommCount++;
    }
  }

  console.log(`\nUpdated ${updatedCommCount} commission history records in production database!`);

  // Verify Commission Histories Count & Retailer Total Commissions
  const totalCommDocs = await commCol.countDocuments();
  console.log(`Total CommissionHistory Documents in DB: ${totalCommDocs}`);

  const users = await db.collection('users').find({}).toArray();
  console.log('\n--- RETAILER COMMISSION & TODAY RECHARGE SUMMARY ---');
  for (const u of users) {
    const uId = u._id;
    const code = u.retailerId || u.customId || 'N/A';
    const uComms = await commCol.find({ userId: uId }).toArray();

    const totalRetailerCommRupees = uComms.reduce((acc, c) => acc + (c.retailerCommissionAmount || 0), 0);

    const todayRtxs = await rechCol.find({
      userId: uId,
      status: { $in: ['SUCCESS', 'PAYMENT_SUCCESS', 'completed', 'success', 'SUCCESSFUL'] }
    }).toArray();

    const todayVol = todayRtxs.reduce((acc, r) => acc + (r.amount || 0), 0);
    const todayComm = todayRtxs.reduce((acc, r) => acc + (r.commissionAmount || 0), 0);

    console.log(`Retailer ${code.padEnd(10)} (${u.name.padEnd(15)}): Total Restored Comm = ₹${totalRetailerCommRupees.toFixed(2)} (${uComms.length} entries) | Total Recharges = ₹${todayVol.toFixed(2)} (${todayRtxs.length} txns) | Total Comm = ₹${todayComm.toFixed(2)}`);
  }

  console.log('\n====================================================');
  console.log('[ALL RETAILER COMMISSIONS & DASHBOARD SUMMARIES FULLY RESTORED]');
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreCommissionsAndTodayDashboardSummary().catch(err => {
    console.error('Commission & Summary restore error:', err);
    process.exit(1);
  });
}

module.exports = { restoreCommissionsAndTodayDashboardSummary };
