const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const Notification = require('../models/Notification');

async function checkFailed() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  const failed = await RechargeTransaction.find({ status: { $in: ['FAILED', 'REFUNDED'] } })
    .sort({ updatedAt: -1 })
    .limit(10)
    .lean();

  console.log('Sample of recently failed/refunded transactions:');
  failed.forEach(t => {
    console.log(`- Order: ${t.orderId}, Status: ${t.status}, RefundStatus: ${t.refundStatus}, RefundAmount: ₹${t.refundAmount}, Reason: ${t.failureReason}`);
  });

  const notifs = await Notification.find({ notificationType: 'RECHARGE_FAILED' })
    .sort({ createdAt: -1 })
    .limit(5)
    .lean();
  console.log('\nSample RECHARGE_FAILED notifications:');
  notifs.forEach(n => {
    console.log(`- User: ${n.userId}, Order: ${n.relatedOrderId}, Title: ${n.title}, Message: ${n.message}`);
  });

  await mongoose.disconnect();
}
checkFailed().catch(console.error);
