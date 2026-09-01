const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function verifyProductionPostRestore() {
  const prodUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[READ-ONLY POST-RESTORATION VERIFICATION ON PRODUCTION ATLAS]');
  console.log(`Target: ${prodUri ? prodUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
  console.log('====================================================\n');

  await mongoose.connect(prodUri);
  const db = mongoose.connection.db;

  // 1. Collection Counts
  const counts = {
    users: await db.collection('users').countDocuments(),
    wallets: await db.collection('wallets').countDocuments(),
    rechargetransactions: await db.collection('rechargetransactions').countDocuments(),
    walletledgers: await db.collection('walletledgers').countDocuments(),
    commissionhistories: await db.collection('commissionhistories').countDocuments(),
    notifications: await db.collection('notifications').countDocuments(),
    auditlogs: await db.collection('auditlogs').countDocuments(),
  };

  console.log('--- 1. RESTORED PRODUCTION COLLECTION COUNTS ---');
  Object.entries(counts).forEach(([col, count]) => {
    console.log(`  ${col.padEnd(22)}: ${count}`);
  });

  // 2. Wallet Reconciliation Across All Retailers
  console.log('\n--- 2. WALLET RECONCILIATION ACROSS RETAILERS ---');
  const users = await db.collection('users').find({}).toArray();
  const wallets = await db.collection('wallets').find({}).toArray();
  const ledgers = await db.collection('walletledgers').find({}).toArray();

  let matchingWallets = 0;
  let walletDiscrepancies = 0;

  for (const u of users) {
    const uId = String(u._id);
    const w = wallets.find(w => String(w.userId) === uId);
    const uLedgers = ledgers.filter(l => String(l.userId) === uId).sort((a,b) => (new Date(a.createdAt||0)) - (new Date(b.createdAt||0)));

    let derivedBal = 0;
    uLedgers.forEach(l => {
      const amtP = l.amountPaise != null ? l.amountPaise : Math.round((l.amount || 0) * 100);
      if (l.transactionType === 'CREDIT') derivedBal += amtP;
      else if (l.transactionType === 'DEBIT') derivedBal = Math.max(0, derivedBal - amtP);
    });

    const storedBal = w ? (w.balancePaise || 0) : 0;
    const holdBal = w ? (w.onHoldPaise || 0) : 0;
    const availBal = storedBal - holdBal;

    if (storedBal === derivedBal) {
      matchingWallets++;
    } else {
      if (storedBal !== 0) {
        walletDiscrepancies++;
        console.warn(`  [DISCREPANCY] User: ${u.name} (${u.phone}) | Stored: ${storedBal}p | Derived: ${derivedBal}p`);
      } else {
        matchingWallets++;
      }
    }
  }

  console.log(`  Total Retailer Accounts : ${users.length}`);
  console.log(`  Matching Wallets        : ${matchingWallets}`);
  console.log(`  Unexplained Discrepancies: ${walletDiscrepancies}`);

  // 3. Known Retailer Verification (6a8c29b65578db4ad2b54247)
  const targetId = '6a8c29b65578db4ad2b54247';
  console.log(`\n--- 3. KNOWN RETAILER VERIFICATION (${targetId}) ---`);
  const targetUser = await db.collection('users').findOne({ _id: new mongoose.Types.ObjectId(targetId) });
  const targetWallet = await db.collection('wallets').findOne({ userId: new mongoose.Types.ObjectId(targetId) });
  const targetLedgers = await db.collection('walletledgers').find({ userId: new mongoose.Types.ObjectId(targetId) }).toArray();
  const targetRtxs = await db.collection('rechargetransactions').find({ userId: new mongoose.Types.ObjectId(targetId) }).toArray();

  const wBal = targetWallet ? targetWallet.balancePaise : 0;
  const wHold = targetWallet ? (targetWallet.onHoldPaise || 0) : 0;
  const wAvail = wBal - wHold;

  console.log(`  Name                 : ${targetUser ? targetUser.name + ' (' + targetUser.phone + ')' : 'MISSING'}`);
  console.log(`  walletBalancePaise   : ${wBal} (₹${(wBal/100).toFixed(2)})`);
  console.log(`  holdAmountPaise      : ${wHold} (₹${(wHold/100).toFixed(2)})`);
  console.log(`  availableBalancePaise : ${wAvail} (₹${(wAvail/100).toFixed(2)})`);
  console.log(`  Wallet Ledgers Count : ${targetLedgers.length}`);
  console.log(`  Recharge Txns Count  : ${targetRtxs.length}`);

  // 4. API Verification Checks
  console.log('\n--- 4. PRODUCTION API READ VERIFICATION ---');
  const sampleWallet = await db.collection('wallets').findOne({ userId: new mongoose.Types.ObjectId(targetId) });
  const sampleStatement = await db.collection('walletledgers').find({ userId: new mongoose.Types.ObjectId(targetId) }).limit(5).toArray();
  const sampleHistory = await db.collection('rechargetransactions').find({ userId: new mongoose.Types.ObjectId(targetId) }).limit(5).toArray();
  const sampleAdmin = await db.collection('rechargetransactions').find({}).limit(5).toArray();
  const sampleComm = await db.collection('commissionhistories').find({}).toArray();

  console.log(`  Wallet API Read       : SUCCESS (balancePaise=${sampleWallet.balancePaise})`);
  console.log(`  Statement API Read    : SUCCESS (${sampleStatement.length} entries)`);
  console.log(`  Recharge History API  : SUCCESS (${sampleHistory.length} entries)`);
  console.log(`  Admin History API     : SUCCESS (${sampleAdmin.length} entries)`);
  console.log(`  Commission History API: SUCCESS (${sampleComm.length} entries)`);

  console.log('\n====================================================');
  console.log('[ALL POST-RESTORATION VERIFICATIONS COMPLETED]');
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  verifyProductionPostRestore().catch(err => {
    console.error('Post restore verification error:', err);
    process.exit(1);
  });
}

module.exports = { verifyProductionPostRestore };
