const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const User = require('../models/User');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');

async function inspectUser() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('\n====================================================');
  console.log('[INSPECT USER & TRANSACTIONS FOR RET000013]');

  // Find user by customId RET000013 or name Srujan
  const user = await User.findOne({ $or: [{ customId: 'RET000013' }, { name: /srujan/i }] }).lean();
  if (!user) {
    console.log('User RET000013 / Srujan not found in DB!');
    await mongoose.disconnect();
    return;
  }

  console.log(`Found User: _id: ${user._id}, name: "${user.name}", email: "${user.email}", customId: "${user.customId}", accountType: "${user.accountType}"`);

  // Find all RechargeTransaction documents for this user
  const recharges = await RechargeTransaction.find({ userId: user._id }).sort({ createdAt: -1 }).lean();
  console.log(`\nRechargeTransaction count: ${recharges.length}`);
  recharges.forEach((tx, idx) => {
    console.log(`${idx + 1}. orderId: ${tx.orderId}, amount: ₹${tx.amount}, comm: ₹${tx.commissionAmount}, status: "${tx.status}", createdAt: ${tx.createdAt}, completedAt: ${tx.completedAt}`);
  });

  // Find all Transaction documents for this user
  const txs = await Transaction.find({ userId: user._id }).sort({ createdAt: -1 }).lean();
  console.log(`\nTransaction count: ${txs.length}`);
  txs.forEach((tx, idx) => {
    console.log(`${idx + 1}. refId: ${tx.referenceId}, amountPaise: ${tx.amountPaise}, status: "${tx.status}", type: "${tx.type}", createdAt: ${tx.createdAt}`);
  });

  console.log('====================================================\n');
  await mongoose.disconnect();
}

inspectUser().catch(console.error);
