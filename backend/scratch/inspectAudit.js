const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    
    console.log('\n--- USERS (Sample) ---');
    const users = await mongoose.connection.db.collection('users').find({}).toArray();
    console.log(`Total Users: ${users.length}`);
    users.forEach(u => console.log(`User: ${u._id} | Phone: ${u.phone} | Name: ${u.name} | Role: ${u.role} | RetailerId: ${u.retailerId}`));

    console.log('\n--- WALLETS ---');
    const wallets = await mongoose.connection.db.collection('wallets').find({}).toArray();
    console.log(wallets);

    console.log('\n--- RECHARGE TRANSACTIONS ---');
    const rtxs = await mongoose.connection.db.collection('rechargetransactions').find({}).toArray();
    console.log(rtxs);

    console.log('\n--- GLOBAL TRANSACTIONS ---');
    const gtxs = await mongoose.connection.db.collection('transactions').find({}).toArray();
    console.log(gtxs);

    console.log('\n--- NOTIFICATIONS SAMPLE ---');
    const notifs = await mongoose.connection.db.collection('notifications').find({}).sort({ createdAt: -1 }).limit(20).toArray();
    notifs.forEach(n => console.log(`[Notif ${n.createdAt}] ${n.userId} | ${n.title} | ${n.message}`));

    console.log('\n--- AUDIT LOGS SAMPLE ---');
    const audits = await mongoose.connection.db.collection('auditlogs').find({}).sort({ createdAt: -1 }).limit(20).toArray();
    audits.forEach(a => console.log(`[Audit ${a.createdAt}]`, a));

  } catch (e) {
    console.error('Error:', e);
  } finally {
    await mongoose.disconnect();
  }
})();
