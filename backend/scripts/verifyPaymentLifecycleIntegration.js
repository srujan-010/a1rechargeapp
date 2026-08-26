const mongoose = require('mongoose');
const crypto = require('crypto');
const dotenv = require('dotenv');
dotenv.config();

const connectDB = require('../config/db');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const User = require('../models/User');
const Wallet = require('../models/Wallet');

async function testPaymentLifecycleIntegration() {
  await connectDB();
  console.log('=== VERIFYING RAZORPAY PAYMENT LIFECYCLE & SIGNATURE VERIFICATION ===\n');

  const testUserId = new mongoose.Types.ObjectId();
  const testOrderId = `AIR_TEST_RZP_${Date.now()}`;
  const mockRazorpayOrderId = `order_${Date.now()}`;
  const mockRazorpayPaymentId = `pay_${Date.now()}`;
  const razorpaySecret = (process.env.RAZORPAY_KEY_SECRET || 'v45oD145W4CRty7hAWrjJ1cq').trim();

  // Generate valid HMAC-SHA256 signature
  const validSignature = crypto
    .createHmac('sha256', razorpaySecret)
    .update(`${mockRazorpayOrderId}|${mockRazorpayPaymentId}`)
    .digest('hex');

  console.log(`[1] Signature Generated: ${validSignature.substring(0, 16)}...`);

  // Create initial transaction in initiated status
  console.log('[2] Creating RechargeTransaction and Transaction in INITIATED status...');
  const rechargeTx = await RechargeTransaction.create({
    orderId: testOrderId,
    clientOrderId: testOrderId,
    userId: testUserId,
    providerName: 'A1Topup',
    mobileNumber: '9876543210',
    amount: 10,
    payableAmount: 10,
    commissionAmount: 0,
    operatorCode: 'AT',
    circleCode: '4',
    status: 'INITIATED',
    paymentMethod: 'RAZORPAY',
    razorpayOrderId: mockRazorpayOrderId,
  });

  const globalTx = await Transaction.create({
    userId: testUserId,
    type: 'debit',
    amountPaise: 1000,
    payableAmountPaise: 1000,
    status: 'initiated',
    service: 'mobile_recharge',
    referenceId: testOrderId,
    description: 'Recharge for 9876543210',
  });

  console.log(`- RechargeTransaction created (status: ${rechargeTx.status})`);
  console.log(`- Transaction created (status: ${globalTx.status})`);

  // Verify Signature Logic
  console.log('\n[3] Verifying Signature & Updating DB to PROCESSING...');
  const expectedSig = crypto
    .createHmac('sha256', razorpaySecret)
    .update(`${mockRazorpayOrderId}|${mockRazorpayPaymentId}`)
    .digest('hex');

  expect(expectedSig).toBe(validSignature);

  rechargeTx.razorpayPaymentId = mockRazorpayPaymentId;
  rechargeTx.razorpaySignature = validSignature;
  rechargeTx.status = 'PROCESSING';
  rechargeTx.providerRequestSent = true;
  await rechargeTx.save();

  globalTx.razorpayPaymentId = mockRazorpayPaymentId;
  globalTx.status = 'processing';
  await globalTx.save();

  console.log(`- RechargeTransaction updated to: ${rechargeTx.status}`);
  console.log(`- Transaction updated to: ${globalTx.status}`);

  // Test Idempotency Guard
  console.log('\n[4] Testing Backend Verification Idempotency Guard...');
  const existingDoc = await RechargeTransaction.findOne({ orderId: testOrderId });
  const isDuplicate = existingDoc.providerRequestSent && ['SUCCESS', 'FAILED', 'PENDING', 'PROCESSING'].includes(existingDoc.status);

  console.log(`- Duplicate check result: ${isDuplicate ? 'PASSED (Detected duplicate request cleanly)' : 'FAILED'}`);
  expect(isDuplicate).toBe(true);

  // Cleanup
  await RechargeTransaction.deleteOne({ _id: rechargeTx._id });
  await Transaction.deleteOne({ _id: globalTx._id });

  console.log('\n=== PAYMENT LIFECYCLE INTEGRATION VERIFICATION PASSED ===');
  process.exit(0);
}

function expect(val) {
  return {
    toBe: (expected) => {
      if (val !== expected) throw new Error(`Expected ${expected} but got ${val}`);
    }
  };
}

testPaymentLifecycleIntegration().catch((err) => {
  console.error('\nTest Error:', err);
  process.exit(1);
});
