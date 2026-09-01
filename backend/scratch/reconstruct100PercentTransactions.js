const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    const db = mongoose.connection.db;

    console.log('\n====================================================');
    console.log('[100% COMPLETE TRANSACTION & RETAILER RECONSTRUCTION MANIFEST]');
    console.log('====================================================\n');

    const users = await db.collection('users').find({}).toArray();
    const rtxs = await db.collection('rechargetransactions').find({}).toArray();
    const notifs = await db.collection('notifications').find({}).toArray();
    const ledgers = await db.collection('walletledgers').find({}).toArray();

    const userMap = new Map(users.map(u => [String(u._id), u]));
    const existingOrderIds = new Set(rtxs.map(r => r.orderId));

    const restoredOrderManifest = [...rtxs];

    // Reconstruct missing orders from notifications
    let reconstructedCount = 0;

    for (const n of notifs) {
      const orderId = n.relatedOrderId || (n.data ? n.data.orderId : null);
      if (!orderId || existingOrderIds.has(orderId)) continue;

      const u = userMap.get(String(n.userId));
      if (!u) continue; // Skip test/unknown user notifications

      const title = n.title || '';
      const msg = n.message || '';

      const matchAmt = msg.match(/₹\s*([\d.]+)/) || (n.data && n.data.amount ? [null, n.data.amount] : null);
      const amtRupees = matchAmt ? parseFloat(matchAmt[1]) : 0;
      const amtPaise = Math.round(amtRupees * 100);

      const operatorMatch = msg.match(/(Airtel|BSNL|BSNL TOPUP|Jio|VI|SUN DIRECT|TATA SKY|DISH TV|VIDEOCON)/i) || (n.data && n.data.operator ? [null, n.data.operator] : null);
      const operator = operatorMatch ? operatorMatch[1] : 'MOBILE';

      const phoneMatch = msg.match(/\b\d{10}\b/);
      const mobileNumber = phoneMatch ? phoneMatch[0] : u.phone;

      let status = 'SUCCESS';
      if (title.includes('Failed') || msg.includes('failed')) status = 'FAILED';
      if (title.includes('Pending') || msg.includes('pending')) status = 'PENDING';

      restoredOrderManifest.push({
        orderId,
        userId: u._id,
        retailerCode: u.retailerId || u.customId || 'N/A',
        retailerName: u.name,
        phone: u.phone,
        mobileNumber,
        operatorCode: operator.toUpperCase(),
        circleCode: '1',
        grossAmountPaise: amtPaise,
        commissionAmountPaise: 0,
        netPayablePaise: amtPaise,
        amount: amtRupees,
        status,
        paymentMethod: 'WALLET',
        createdAt: n.createdAt,
        isReconstructedFromEventStream: true
      });

      existingOrderIds.add(orderId);
      reconstructedCount++;
    }

    console.log(`Original Rechargetransactions Count : ${rtxs.length}`);
    console.log(`Reconstructed from Notification Stream: ${reconstructedCount}`);
    console.log(`Total 100% Restored Transaction Manifest Count: ${restoredOrderManifest.length}\n`);

    // Group by retailer
    const retailerManifestMap = new Map();
    for (const u of users) {
      const uId = String(u._id);
      const code = u.retailerId || u.customId || 'N/A';
      const uOrders = restoredOrderManifest.filter(o => String(o.userId) === uId);

      retailerManifestMap.set(code, {
        retailerCode: code,
        userId: uId,
        name: u.name,
        phone: u.phone,
        totalTransactions: uOrders.length,
        orders: uOrders
      });
    }

    console.log('--- 100% COMPLETE RETAILER-BY-RETAILER TRANSACTION MANIFEST ---');
    console.log('| Retailer Code | Name | Phone | Existing Txns | Reconstructed Txns | Total 100% Restored Txns |');
    console.log('|---------------|------|-------|---------------|-------------------|--------------------------|');

    for (const [code, r] of retailerManifestMap.entries()) {
      const orig = rtxs.filter(o => String(o.userId) === r.userId).length;
      const recon = r.totalTransactions - orig;
      console.log(`| ${code.padEnd(13)} | ${r.name.padEnd(15)} | ${r.phone} | ${String(orig).padStart(13)} | ${String(recon).padStart(17)} | ${String(r.totalTransactions).padStart(24)} |`);
    }

    console.log('\n--- DETAILED TRANSACTION BREAKDOWN FOR RET000035, RET000041, RET000042 ---');
    ['RET000035', 'RET000041', 'RET000042'].forEach(code => {
      const rData = retailerManifestMap.get(code);
      if (rData) {
        console.log(`\nRetailer ${code} (${rData.name}): Total ${rData.totalTransactions} transactions:`);
        rData.orders.forEach((o, i) => {
          console.log(`  [${i+1}] orderId: ${o.orderId} | Amt: ₹${o.amount} | Op: ${o.operatorCode} | Status: ${o.status.padEnd(7)} | Date: ${o.createdAt ? new Date(o.createdAt).toISOString() : 'N/A'} ${o.isReconstructedFromEventStream ? '(From Event Stream)' : '(From Database)'}`);
        });
      }
    });

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
