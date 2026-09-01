const mongoose = require('mongoose');

const tempUri = 'mongodb://localhost:27017/a1recharge_restore_verify';

(async () => {
  try {
    await mongoose.connect(tempUri);
    const db = mongoose.connection.db;

    console.log('\n====================================================');
    console.log('[BLOCKER FORENSIC AUDIT REPORT ON TEMP DB]');
    console.log(`URI: ${tempUri}`);
    console.log('====================================================\n');

    // BLOCKER 1 & 2: Investigation of Orders A1R1788269049460482 & A1R1788269967998664
    console.log('--- BLOCKER 1 & 2: MISSING ORDERS DEEP SEARCH ---');
    const targetOrders = ['A1R1788269049460482', 'A1R1788269967998664'];
    const allCollections = await db.listCollections().toArray();

    for (const orderId of targetOrders) {
      console.log(`\nOrder: ${orderId}`);
      for (const col of allCollections) {
        const matches = await db.collection(col.name).find({
          $or: [
            { orderId },
            { relatedOrderId: orderId },
            { referenceId: orderId },
            { description: new RegExp(orderId) },
            { message: new RegExp(orderId) }
          ]
        }).toArray();
        if (matches.length > 0) {
          console.log(`  Collection [${col.name}] matches: ${matches.length}`);
          matches.forEach(m => console.log('    Doc:', JSON.stringify(m, null, 2)));
        }
      }
    }

    // BLOCKER 3: MAHESH GANJI (6a92e63746d76f240a5dd82d) DEEP AUDIT
    console.log('\n--- BLOCKER 3: MAHESH GANJI (6a92e63746d76f240a5dd82d) COMPLETE LEDGER & AUDIT TRAIL ---');
    const maheshId = '6a92e63746d76f240a5dd82d';
    const maheshUser = await db.collection('users').findOne({ _id: new mongoose.Types.ObjectId(maheshId) });
    const maheshWallet = await db.collection('wallets').findOne({ userId: new mongoose.Types.ObjectId(maheshId) });
    const maheshLedgers = await db.collection('walletledgers').find({ userId: new mongoose.Types.ObjectId(maheshId) }).sort({ createdAt: 1 }).toArray();
    const maheshAudits = await db.collection('auditlogs').find({ $or: [{ adminId: new mongoose.Types.ObjectId(maheshId) }, { resourceId: new mongoose.Types.ObjectId(maheshId) }] }).sort({ createdAt: 1 }).toArray();

    console.log(`User: ${maheshUser ? maheshUser.name + ' (' + maheshUser.phone + ')' : 'MISSING'}`);
    console.log(`Stored Wallet: bal=${maheshWallet ? maheshWallet.balancePaise : 0}p (₹${(maheshWallet ? maheshWallet.balancePaise/100 : 0).toFixed(2)}), hold=${maheshWallet ? maheshWallet.onHoldPaise : 0}p`);
    console.log(`Audit Logs (${maheshAudits.length}):`);
    maheshAudits.forEach(a => console.log('  Audit:', JSON.stringify(a, null, 2)));

    console.log(`\nLedger Entries (${maheshLedgers.length}):`);
    let cumulativeBalPaise = 0;
    maheshLedgers.forEach((l, i) => {
      const amtP = l.amountPaise != null ? l.amountPaise : Math.round((l.amount || 0) * 100);
      if (l.transactionType === 'CREDIT') cumulativeBalPaise += amtP;
      else if (l.transactionType === 'DEBIT') cumulativeBalPaise -= amtP;
      console.log(`  [${i+1}] ${l.createdAt ? new Date(l.createdAt).toISOString() : 'N/A'} | Type: ${l.transactionType.padEnd(6)} | Amt: ${amtP}p (₹${(amtP/100).toFixed(2)}) | StoredAfter: ${l.balanceAfterPaise || Math.round((l.balanceAfter||0)*100)}p | CalcCumulative: ${cumulativeBalPaise}p | Ref: ${l.referenceType} | Desc: ${l.description || l.remark || ''}`);
    });

    // BLOCKER 4: TEST RETAILER (9999999999)
    console.log('\n--- BLOCKER 4: TEST RETAILER (9999999999) AUDIT ---');
    const testUsers = await db.collection('users').find({ phone: { $in: ['9999999999', '9888877777', '9999900000', '9999000001', '9999000002'] } }).toArray();
    for (const tu of testUsers) {
      const tuWallet = await db.collection('wallets').findOne({ userId: tu._id });
      const tuLedgers = await db.collection('walletledgers').find({ userId: tu._id }).toArray();
      const tuRtxs = await db.collection('rechargetransactions').find({ userId: tu._id }).toArray();
      console.log(`Test User: ${tu.name} (${tu.phone}) | ID: ${tu._id} | Created: ${tu.createdAt}`);
      console.log(`  Wallet: bal=${tuWallet ? tuWallet.balancePaise : 0}p | Ledgers: ${tuLedgers.length} | Recharges: ${tuRtxs.length}`);
    }

    // BLOCKER 5: ALL 36 RETAILER RECONCILIATION TABLE
    console.log('\n--- BLOCKER 5: ALL 36 RETAILER RECONCILIATION TABLE ---');
    const users = await db.collection('users').find({}).toArray();
    const wallets = await db.collection('wallets').find({}).toArray();
    const ledgers = await db.collection('walletledgers').find({}).toArray();
    const walletMap = new Map(wallets.map(w => [String(w.userId), w]));

    const reconciliationReport = [];

    for (const u of users) {
      const uId = String(u._id);
      const w = walletMap.get(uId);
      const uLedgers = ledgers.filter(l => String(l.userId) === uId).sort((a,b) => (new Date(a.createdAt||0)) - (new Date(b.createdAt||0)));

      let derivedBalPaise = 0;
      uLedgers.forEach(l => {
        const amtP = l.amountPaise != null ? l.amountPaise : Math.round((l.amount || 0) * 100);
        if (l.transactionType === 'CREDIT') derivedBalPaise += amtP;
        else if (l.transactionType === 'DEBIT') derivedBalPaise = Math.max(0, derivedBalPaise - amtP);
      });

      const storedBalPaise = w ? (w.balancePaise || 0) : 0;
      const holdPaise = w ? (w.onHoldPaise || 0) : 0;
      const availPaise = storedBalPaise - holdPaise;
      const diffPaise = storedBalPaise - derivedBalPaise;
      const isTestUser = ['9999999999', '9888877777', '9999900000', '9999000001', '9999000002'].includes(u.phone);

      let diffReason = 'MATCH';
      if (diffPaise !== 0) {
        if (u.phone === '9421729792') diffReason = 'Aug 30 Admin Audit Log Balance Baseline vs Accumulated Ledgers';
        else if (isTestUser) diffReason = 'Synthetic Test User Created During Jest Run';
        else diffReason = `Unexplained Discrepancy (${diffPaise}p)`;
      }

      reconciliationReport.push({
        retailerId: uId,
        name: u.name,
        phone: u.phone,
        isSyntheticTestUser: isTestUser,
        storedBalancePaise: storedBalPaise,
        holdPaise,
        availablePaise: availPaise,
        ledgerDerivedBalancePaise: derivedBalPaise,
        differencePaise: diffPaise,
        differenceReason: diffReason
      });
    }

    // Sort difference != 0 first
    reconciliationReport.sort((a, b) => Math.abs(b.differencePaise) - Math.abs(a.differencePaise));

    console.log('| Retailer ID | Name | Phone | Synthetic? | Stored Bal | Hold | Available | Derived Bal | Diff | Reason |');
    console.log('|-------------|------|-------|------------|------------|------|-----------|-------------|------|--------|');
    reconciliationReport.forEach(r => {
      console.log(`| ${r.retailerId} | ${r.name.padEnd(15)} | ${r.phone} | ${String(r.isSyntheticTestUser).padEnd(5)} | ₹${(r.storedBalancePaise/100).toFixed(2)} | ₹${(r.holdPaise/100).toFixed(2)} | ₹${(r.availablePaise/100).toFixed(2)} | ₹${(r.ledgerDerivedBalancePaise/100).toFixed(2)} | ₹${(r.differencePaise/100).toFixed(2)} | ${r.differenceReason} |`);
    });

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
