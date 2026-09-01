const mongoose = require('mongoose');

const tempUri = 'mongodb://localhost:27017/a1recharge_restore_verify';

(async () => {
  try {
    await mongoose.connect(tempUri);
    const db = mongoose.connection.db;

    console.log('\n====================================================');
    console.log('[FINAL PRE-PROMOTION VERIFICATION REPORT ON TEMP DB]');
    console.log(`URI: ${tempUri}`);
    console.log('====================================================\n');

    // 1. NOTIFICATION COUNT DISCREPANCY ANALYSIS (828 vs 842)
    const notifs = await db.collection('notifications').find({}).sort({ createdAt: 1 }).toArray();
    console.log(`Total Notifications in Temp DB: ${notifs.length}`);

    // Find the 14 newest notifications (or notifications created around test run time)
    const notifsSortedByDateDesc = await db.collection('notifications').find({}).sort({ createdAt: -1 }).limit(14).toArray();
    console.log('\n--- 1. 14 ADDITIONAL NOTIFICATION RECORDS ---');
    notifsSortedByDateDesc.reverse().forEach((n, idx) => {
      console.log(`[${idx + 1}] Notif ID: ${n._id} | User: ${n.userId} | Order: ${n.relatedOrderId || 'N/A'} | Created: ${n.createdAt ? new Date(n.createdAt).toISOString() : 'N/A'} | Title: ${n.title} | Msg: ${n.message}`);
    });

    // 2. KNOWN ORDER DEEP FORENSIC AUDIT
    const knownOrders = [
      'A1R1788269049460482',
      'A1R1788269967998664',
      'A1DTH1788000251411281',
      'A1R178800529290026',
      'A1R1787993147505684',
      'A1R1788266552471870'
    ];

    console.log('\n--- 2. KNOWN ORDERS MULTI-COLLECTION FORENSIC AUDIT ---');
    const cols = ['rechargetransactions', 'transactions', 'walletledgers', 'commissionhistories', 'notifications', 'auditlogs', 'transactionactionlogs', 'notificationhistories'];

    for (const orderId of knownOrders) {
      console.log(`\nOrder ID: ${orderId}`);
      for (const colName of cols) {
        const found = await db.collection(colName).findOne({
          $or: [
            { orderId },
            { relatedOrderId: orderId },
            { referenceId: orderId },
            { description: new RegExp(orderId) },
            { message: new RegExp(orderId) }
          ]
        });
        if (found) {
          console.log(`  - ${colName.padEnd(23)}: EXISTS | ID: ${found._id} | Status: ${found.status || 'N/A'} | Amt: ${found.amount || found.grossAmountPaise || 'N/A'}`);
        } else {
          console.log(`  - ${colName.padEnd(23)}: MISSING`);
        }
      }
    }

    // 3. ALL 147 RECHARGE TRANSACTIONS & CORRESPONDING FINANCIAL RECORDS
    const rtxs = await db.collection('rechargetransactions').find({}).sort({ createdAt: 1 }).toArray();
    const ledgers = await db.collection('walletledgers').find({}).toArray();
    const comms = await db.collection('commissionhistories').find({}).toArray();

    console.log(`\n--- 3. VERIFY ALL ${rtxs.length} RECHARGE TRANSACTIONS & LEDGERS ---`);
    let matchedLedgerCount = 0;
    let unmatchedLedgerCount = 0;

    rtxs.forEach(r => {
      const match = ledgers.find(l => l.referenceId === r.orderId || (l.description || '').includes(r.orderId));
      if (match) matchedLedgerCount++;
      else unmatchedLedgerCount++;
    });

    console.log(`Recharge Transactions Total : ${rtxs.length}`);
    console.log(`Matched with Wallet Ledgers : ${matchedLedgerCount}`);
    console.log(`Unmatched (e.g. UPI/Pending): ${unmatchedLedgerCount}`);

    // 4. FINAL WALLET BALANCE & LEDGER DERIVED CHECK
    console.log('\n--- 4. ALL 36 RETAILER WALLET BALANCE VS LEDGER-DERIVED CHECK ---');
    const users = await db.collection('users').find({}).toArray();
    const wallets = await db.collection('wallets').find({}).toArray();
    let balanceDiscrepancies = 0;

    for (const u of users) {
      const uId = String(u._id);
      const w = wallets.find(w => String(w.userId) === uId);
      const uLedgers = ledgers.filter(l => String(l.userId) === uId).sort((a,b) => (new Date(a.createdAt||0)) - (new Date(b.createdAt||0)));

      let calculatedBalPaise = 0;
      for (const l of uLedgers) {
        const amtP = l.amountPaise != null ? l.amountPaise : Math.round((l.amount || 0) * 100);
        if (l.transactionType === 'CREDIT') {
          calculatedBalPaise += amtP;
        } else if (l.transactionType === 'DEBIT') {
          calculatedBalPaise = Math.max(0, calculatedBalPaise - amtP);
        }
      }

      const storedBalPaise = w ? (w.balancePaise || 0) : 0;
      const holdPaise = w ? (w.onHoldPaise || 0) : 0;
      const availPaise = storedBalPaise - holdPaise;
      const diff = Math.abs(storedBalPaise - calculatedBalPaise);

      if (diff !== 0 && storedBalPaise !== 0) {
        console.warn(`[BALANCE MISMATCH] User ${u.name} (${u.phone}): Stored=${storedBalPaise}p | Derived=${calculatedBalPaise}p | Diff=${diff}p`);
        balanceDiscrepancies++;
      }
    }
    console.log(`Total Retailers Checked: ${users.length}`);
    console.log(`Balance Discrepancies Count: ${balanceDiscrepancies}`);

    // 5. DUPLICATE DEBIT CHECK
    console.log('\n--- 5. FINAL DUPLICATE DEBIT & PAYMENT METHOD CHECK ---');
    let duplicateDebits = 0;
    let upiWalletMutations = 0;
    let failedWalletDebits = 0;

    for (const r of rtxs) {
      const orderLedgers = ledgers.filter(l => l.referenceId === r.orderId || (l.description || '').includes(r.orderId));
      const debits = orderLedgers.filter(l => l.transactionType === 'DEBIT');

      if (r.paymentMethod === 'WALLET') {
        if (r.status === 'SUCCESS' && debits.length > 1) {
          duplicateDebits++;
        }
        if (r.status === 'FAILED' && debits.length > 0) {
          failedWalletDebits++;
        }
      } else if (r.paymentMethod === 'RAZORPAY_UPI' || r.paymentMethod === 'UPI') {
        if (debits.length > 0) {
          upiWalletMutations++;
        }
      }
    }

    console.log(`Duplicate Wallet Debits  : ${duplicateDebits}`);
    console.log(`UPI Wallet Mutations     : ${upiWalletMutations}`);
    console.log(`Failed Wallet Debits     : ${failedWalletDebits}`);

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
