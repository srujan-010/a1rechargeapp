const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    const notifs = await mongoose.connection.db.collection('notifications').find({}).toArray();
    console.log(`Total notifications: ${notifs.length}`);

    const userNotifSummary = {};
    for (const n of notifs) {
      const uid = String(n.userId);
      if (!userNotifSummary[uid]) {
        userNotifSummary[uid] = { count: 0, msgs: [] };
      }
      userNotifSummary[uid].count++;
      userNotifSummary[uid].msgs.push(`${n.title}: ${n.message}`);
    }

    const users = await mongoose.connection.db.collection('users').find({}).toArray();
    for (const u of users) {
      const uid = String(u._id);
      const summary = userNotifSummary[uid];
      if (summary && summary.count > 0) {
        console.log(`\n====================================================`);
        console.log(`User: ${u.name} | Phone: ${u.phone} | ID: ${uid} | Notif Count: ${summary.count}`);
        console.log('Sample Notifications:');
        summary.msgs.slice(0, 5).forEach(m => console.log(' - ', m));
      }
    }

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
