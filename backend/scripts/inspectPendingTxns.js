const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const RechargeTransaction = require('../models/RechargeTransaction');

async function inspect() {
  await mongoose.connect(process.env.MONGODB_URI);
  const nonTerminalStatuses = [
    'PENDING', 'pending',
    'PROCESSING', 'processing',
    'RECHARGE_PROCESSING',
    'INITIATED', 'initiated',
    'PAYMENT_PENDING', 'payment_pending'
  ];
  const nonTerminal = await RechargeTransaction.find({
    status: { $in: nonTerminalStatuses }
  }).lean();
  console.log('Total non-terminal recharge transactions:', nonTerminal.length);
  const now = Date.now();
  nonTerminal.forEach((t, i) => {
    const ageMins = Math.round((now - new Date(t.createdAt).getTime()) / 60000);
    console.log(`${i+1}. ID: ${t._id} Order: ${t.orderId} Status: ${t.status} Amount: ₹${t.amount} Method: ${t.paymentMethod} RzpId: ${t.razorpayPaymentId} User: ${t.userId} CreatedAt: ${t.createdAt} Age: ${ageMins}m`);
  });
  await mongoose.disconnect();
}
inspect().catch(console.error);
