const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const knownOrders = [
  'A1R1788269049460482',
  'A1R1788269967998664',
  'A1DTH1788000251411281',
  'A1R178800529290026',
  'A1R1787993147505684',
  'A1R1788266552471870'
];

const knownRetailerId = '6a8c29b65578db4ad2b54247';

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('\n====================================================');
    console.log('[READ-ONLY FORENSIC VERIFICATION OF KNOWN ORDERS & RETAILER]');
    console.log('====================================================\n');

    const db = mongoose.connection.db;

    // 1. Check Known Orders
    console.log('--- KNOWN ORDER AUDIT ---');
    for (const orderId of knownOrders) {
      const rechTx = await db.collection('rechargetransactions').findOne({ orderId });
      const globalTx = await db.collection('transactions').findOne({ orderId });
      const ledger = await db.collection('walletledgers').findOne({ $or: [{ referenceId: orderId }, { 'description': new RegExp(orderId) }] });
      const notif = await db.collection('notifications').findOne({ $or: [{ relatedOrderId: orderId }, { message: new RegExp(orderId) }] });
      const audit = await db.collection('auditlogs').findOne({ description: new RegExp(orderId) });

      console.log(`\nOrder ID: ${orderId}`);
      console.log(`  rechargetransactions: ${rechTx ? 'EXISTS (' + rechTx.status + ', Amount: ₹' + (rechTx.grossAmountPaise ? rechTx.grossAmountPaise/100 : rechTx.amount) + ')' : 'MISSING'}`);
      console.log(`  transactions:         ${globalTx ? 'EXISTS' : 'MISSING'}`);
      console.log(`  walletledgers:        ${ledger ? 'EXISTS (' + ledger.transactionType + ' ₹' + (ledger.amountPaise ? ledger.amountPaise/100 : ledger.amount) + ')' : 'MISSING'}`);
      console.log(`  notifications:        ${notif ? 'EXISTS (' + notif.title + ')' : 'MISSING'}`);
      console.log(`  auditlogs:            ${audit ? 'EXISTS (' + audit.action + ')' : 'MISSING'}`);
    }

    // 2. Check Known Retailer
    console.log('\n--- KNOWN RETAILER AUDIT ---');
    const retailerUser = await db.collection('users').findOne({ _id: new mongoose.Types.ObjectId(knownRetailerId) });
    const retailerWallet = await db.collection('wallets').findOne({ userId: new mongoose.Types.ObjectId(knownRetailerId) });
    const retailerLedgers = await db.collection('walletledgers').find({ userId: new mongoose.Types.ObjectId(knownRetailerId) }).toArray();
    const retailerRecharges = await db.collection('rechargetransactions').find({ userId: new mongoose.Types.ObjectId(knownRetailerId) }).toArray();
    const retailerNotifs = await db.collection('notifications').find({ userId: new mongoose.Types.ObjectId(knownRetailerId) }).toArray();

    console.log(`Retailer ID: ${knownRetailerId}`);
    console.log(`  User Record: ${retailerUser ? retailerUser.name + ' (' + retailerUser.phone + ')' : 'MISSING'}`);
    console.log(`  Wallet Document: ${retailerWallet ? 'balancePaise=' + retailerWallet.balancePaise + ' (₹' + (retailerWallet.balancePaise/100) + ')' : 'MISSING'}`);
    console.log(`  Wallet Ledgers Count: ${retailerLedgers.length}`);
    console.log(`  Recharge Transactions Count: ${retailerRecharges.length}`);
    console.log(`  Notifications Count: ${retailerNotifs.length}`);

    // 3. Schema comparison between 'transactions' and 'rechargetransactions'
    console.log('\n--- SCHEMA COMPARISON: transactions VS rechargetransactions ---');
    const sampleRechTx = await db.collection('rechargetransactions').findOne({});
    const sampleGlobalTx = await db.collection('transactions').findOne({});
    console.log('rechargetransactions sample fields:', sampleRechTx ? Object.keys(sampleRechTx) : 'NONE');
    console.log('transactions sample fields:        ', sampleGlobalTx ? Object.keys(sampleGlobalTx) : 'NONE');

  } catch (e) {
    console.error(e);
  } finally {
    await mongoose.disconnect();
  }
})();
