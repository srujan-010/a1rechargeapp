const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const User = require('../models/User');
const Wallet = require('../models/Wallet');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');

async function removeRet000001() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('\n====================================================');
  console.log('[COMPLETELY REMOVE RET000001 FROM DATABASE]');

  // Search by retailerId, customId, or phone 9999000002
  const users = await User.find({
    $or: [
      { retailerId: 'RET000001' },
      { customId: 'RET000001' },
      { phone: '9999000002' },
      { _id: new mongoose.Types.ObjectId('6a8ffd07f9683a014583dcd0') }
    ]
  }).lean();

  console.log(`Found ${users.length} user document(s) for RET000001:`);

  for (const user of users) {
    console.log(`\n- Target User Found: _id: ${user._id}, name: "${user.name}", phone: "${user.phone}", retailerId: "${user.retailerId}"`);

    // 1. Delete Wallet
    const wRes = await Wallet.deleteMany({ userId: user._id });
    console.log(`  -> Deleted ${wRes.deletedCount} Wallet document(s)`);

    // 2. Delete RechargeTransaction
    const rtRes = await RechargeTransaction.deleteMany({ $or: [{ userId: user._id }, { retailerId: 'RET000001' }] });
    console.log(`  -> Deleted ${rtRes.deletedCount} RechargeTransaction document(s)`);

    // 3. Delete Transaction
    const tRes = await Transaction.deleteMany({ $or: [{ userId: user._id }, { retailerId: 'RET000001' }] });
    console.log(`  -> Deleted ${tRes.deletedCount} Transaction document(s)`);

    // 4. Delete User document
    const uRes = await User.deleteOne({ _id: user._id });
    console.log(`  -> Deleted ${uRes.deletedCount} User document (${user._id})`);
  }

  // Double check loose items
  const looseRt = await RechargeTransaction.deleteMany({ retailerId: 'RET000001' });
  const looseT = await Transaction.deleteMany({ retailerId: 'RET000001' });
  console.log(`Loose deletions: ${looseRt.deletedCount} recharges, ${looseT.deletedCount} transactions`);

  console.log('\nSUCCESS: RET000001 has been completely removed from MongoDB.');
  console.log('====================================================\n');

  await mongoose.disconnect();
}

removeRet000001().catch(console.error);
