const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    const db = mongoose.connection.db;

    console.log('\n====================================================');
    console.log('[PHASE 3 READ-ONLY COMPREHENSIVE AUDIT & RECONCILIATION]');
    console.log('====================================================\n');

    const users = await db.collection('users').find({}).toArray();
    const wallets = await db.collection('wallets').find({}).toArray();
    const ledgers = await db.collection('walletledgers').find({}).toArray();
    const rtxs = await db.collection('rechargetransactions').find({}).toArray();
    const notifs = await db.collection('notifications').find({}).toArray();
    const auditlogs = await db.collection('auditlogs').find({}).toArray();
    const commissions = await db.collection('commissionhistories').find({}).toArray();

    // 1. All 36 Retailer Wallets Table
    console.log('--- ALL 36 RETAILER WALLETS TABLE ---');
    const walletMap = new Map(wallets.map(w => [String(w.userId), w]));

    for (const u of users) {
      const uId = String(u._id);
      const w = walletMap.get(uId);
      const uLedgers = ledgers.filter(l => String(l.userId) === uId);
      const uRtxs = rtxs.filter(r => String(r.userId) === uId);
      const uComms = commissions.filter(c => String(c.userId) === uId);
      const uTopups = uLedgers.filter(l => l.referenceType === 'ADD_MONEY' || (l.description || '').includes('added'));

      const bal = w ? (w.balancePaise || 0) : 0;
      const hold = w ? (w.onHoldPaise || 0) : 0;
      const avail = bal - hold;

      console.log(`User: ${u.name.padEnd(20)} | Phone: ${u.phone} | ID: ${uId}`);
      console.log(`  Balance: ₹${(bal/100).toFixed(2)} (${bal}p) | Hold: ₹${(hold/100).toFixed(2)} | Avail: ₹${(avail/100).toFixed(2)}`);
      console.log(`  Ledgers: ${uLedgers.length} | Recharges: ${uRtxs.length} | Commissions: ${uComms.length} | Topups: ${uTopups.length}\n`);
    }

    // 2. Known Retailer Detailed Audit (6a8c29b65578db4ad2b54247)
    const targetRetailerId = '6a8c29b65578db4ad2b54247';
    console.log(`\n--- DETAILED AUDIT FOR KNOWN RETAILER (${targetRetailerId}) ---`);
    const targetUser = users.find(u => String(u._id) === targetRetailerId);
    const targetWallet = wallets.find(w => String(w.userId) === targetRetailerId);
    const targetLedgers = ledgers.filter(l => String(l.userId) === targetRetailerId).sort((a,b) => (a.createdAt || 0) - (b.createdAt || 0));
    const targetRtxs = rtxs.filter(r => String(r.userId) === targetRetailerId);

    console.log(`User: ${targetUser ? targetUser.name + ' (' + targetUser.phone + ')' : 'N/A'}`);
    console.log(`Wallet Balance: ₹${targetWallet ? (targetWallet.balancePaise/100).toFixed(2) : '0.00'} (${targetWallet ? targetWallet.balancePaise : 0} paise)`);
    console.log(`Ledgers Count: ${targetLedgers.length}`);
    console.log('Ledger Entries List:');
    targetLedgers.forEach((l, idx) => {
      console.log(`  [${idx+1}] ${l.createdAt ? l.createdAt.toISOString() : 'N/A'} | Type: ${l.transactionType.padEnd(6)} | Amount: ₹${(l.amountPaise ? l.amountPaise/100 : l.amount).toFixed(2)} | After: ₹${(l.balanceAfterPaise ? l.balanceAfterPaise/100 : l.balanceAfter).toFixed(2)} | Ref: ${l.referenceType} | Desc: ${l.description || l.remark || ''}`);
    });

    // 3. Post-Incident Legitimate Transactions (after 15:30 UTC / 21:00 IST)
    console.log('\n--- POST-INCIDENT TRANSACTIONS CHECK (AFTER 15:30 UTC / 21:00 IST) ---');
    const cutoffDate = new Date('2026-09-01T15:30:00Z');
    const postIncidentTxns = rtxs.filter(r => new Date(r.createdAt || 0) > cutoffDate);
    console.log(`Post-incident transaction count: ${postIncidentTxns.length}`);
    postIncidentTxns.forEach(r => {
      console.log(`  orderId: ${r.orderId} | userId: ${r.userId} | Method: ${r.paymentMethod} | Amount: ₹${r.grossAmountPaise ? r.grossAmountPaise/100 : r.amount} | Status: ${r.status} | Created: ${r.createdAt}`);
    });

    // 4. Financial Integrity & Duplicate Debit Checks
    console.log('\n--- FINANCIAL INTEGRITY & DUPLICATE DEBIT AUDIT ---');
    let duplicateDebitViolations = 0;
    let upiWalletViolations = 0;

    for (const r of rtxs) {
      const orderLedgers = ledgers.filter(l => l.referenceId === r.orderId || (l.description || '').includes(r.orderId));
      if (r.paymentMethod === 'RAZORPAY_UPI' || r.paymentMethod === 'UPI') {
        if (orderLedgers.length > 0) {
          console.warn(`[UPI VIOLATION] Order ${r.orderId} is UPI but has ${orderLedgers.length} wallet ledger entries!`);
          upiWalletViolations++;
        }
      } else if (r.paymentMethod === 'WALLET') {
        const debitEntries = orderLedgers.filter(l => l.transactionType === 'DEBIT');
        if (debitEntries.length > 1) {
          console.warn(`[DUPLICATE DEBIT VIOLATION] Order ${r.orderId} has ${debitEntries.length} debit ledger entries!`);
          duplicateDebitViolations++;
        }
      }
    }
    console.log(`Duplicate Debit Violations: ${duplicateDebitViolations}`);
    console.log(`UPI Wallet Mutation Violations: ${upiWalletViolations}`);

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
