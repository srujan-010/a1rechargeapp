const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    const db = mongoose.connection.db;

    const notifs = await db.collection('notifications').find({}).toArray();
    const rtxs = await db.collection('rechargetransactions').find({}).toArray();
    const users = await db.collection('users').find({}).toArray();

    const userMap = new Map(users.map(u => [String(u._id), u]));
    const existingOrderIds = new Set(rtxs.map(r => r.orderId));

    console.log(`Total Notifications: ${notifs.length}`);
    console.log(`Existing Recharge Transactions: ${rtxs.length}`);

    const missingTxnsFromNotifs = [];

    for (const n of notifs) {
      const orderId = n.relatedOrderId || (n.data ? n.data.orderId : null);
      const title = n.title || '';
      const msg = n.message || '';

      if (orderId && !existingOrderIds.has(orderId)) {
        const u = userMap.get(String(n.userId));
        
        // Parse amount
        const matchAmt = msg.match(/₹\s*([\d.]+)/) || (n.data && n.data.amount ? [null, n.data.amount] : null);
        const amtRupees = matchAmt ? parseFloat(matchAmt[1]) : 0;
        const amtPaise = Math.round(amtRupees * 100);

        // Parse operator
        const operatorMatch = msg.match(/(Airtel|BSNL|BSNL TOPUP|Jio|VI|SUN DIRECT|TATA SKY|DISH TV|VIDEOCON)/i) || (n.data && n.data.operator ? [null, n.data.operator] : null);
        const operator = operatorMatch ? operatorMatch[1] : 'MOBILE';

        // Parse status
        let status = 'SUCCESS';
        if (title.includes('Failed') || msg.includes('failed')) status = 'FAILED';
        if (title.includes('Pending') || msg.includes('pending')) status = 'PENDING';

        missingTxnsFromNotifs.push({
          notifId: n._id,
          orderId,
          userId: n.userId,
          retailerCode: u ? (u.retailerId || u.customId) : 'N/A',
          retailerName: u ? u.name : 'Unknown',
          phone: u ? u.phone : 'N/A',
          amount: amtRupees,
          grossAmountPaise: amtPaise,
          operator,
          status,
          createdAt: n.createdAt,
          message: msg
        });
        // Avoid duplicate orderId processing from multiple notifications
        existingOrderIds.add(orderId);
      }
    }

    console.log(`\nFound ${missingTxnsFromNotifs.length} missing transaction records in notification event log stream:`);
    console.log('| # | Retailer Code | Name | Phone | Order ID | Amount | Operator | Status | Created At |');
    console.log('|---|---------------|------|-------|----------|--------|----------|--------|------------|');
    missingTxnsFromNotifs.forEach((m, i) => {
      console.log(`| ${i+1} | ${m.retailerCode} | ${m.retailerName.padEnd(12)} | ${m.phone} | ${m.orderId} | ₹${m.amount} | ${m.operator.padEnd(10)} | ${m.status.padEnd(7)} | ${m.createdAt ? new Date(m.createdAt).toISOString() : 'N/A'} |`);
    });

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
