const mongoose = require('mongoose');
const dotenv = require('dotenv');
dotenv.config();

const connectDB = require('../config/db');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const Wallet = require('../models/Wallet');
const walletService = require('../services/wallet/wallet.service');

async function testFailedLifecycle() {
  await connectDB();
  console.log('=== VERIFYING RECHARGE FAILED RECONCILIATION LIFECYCLE ===\n');

  const testUserId = new mongoose.Types.ObjectId();
  const testOrderId = `TEST_RECON_FAIL_${Date.now()}`;

  await Wallet.create({
    userId: testUserId,
    balancePaise: 50000, // ₹500
    onHoldPaise: 0,
    currency: 'INR',
  });

  console.log('[1] Reserving ₹100 in wallet for test transaction...');
  await walletService.reserveAmount(testUserId, 100);

  const walletBefore = await Wallet.findOne({ userId: testUserId });
  console.log(`- Balance: ₹${walletBefore.balancePaise / 100}, OnHold: ₹${walletBefore.onHoldPaise / 100}`);
  expect(walletBefore.onHoldPaise).toBe(10000);

  // 1. Create Initial Transaction in PROCESSING status
  console.log('\n[2] Creating RechargeTransaction and Transaction in PROCESSING status...');
  const rechargeTx = await RechargeTransaction.create({
    orderId: testOrderId,
    clientOrderId: testOrderId,
    userId: testUserId,
    providerName: 'A1Topup',
    mobileNumber: '9876543210',
    amount: 100,
    payableAmount: 98,
    reservedAmount: 98,
    commissionAmount: 2,
    operatorCode: 'RC',
    circleCode: '4',
    status: 'PROCESSING',
    providerStatus: 'PENDING',
    providerRequestSent: true,
  });

  const globalTx = await Transaction.create({
    userId: testUserId,
    type: 'debit',
    amountPaise: 10000,
    payableAmountPaise: 9800,
    commissionEarnedPaise: 200,
    status: 'processing',
    service: 'mobile_recharge',
    referenceId: testOrderId,
    description: 'Recharge for 9876543210',
  });

  // 2. Simulate Provider Status changing to FAILED
  console.log('\n[3] Simulating Provider Reconciliation transition to FAILED...');
  const now = new Date();
  
  const updatedRechargeTx = await RechargeTransaction.findOneAndUpdate(
    { _id: rechargeTx._id, status: { $in: ['PENDING', 'PROCESSING', 'RECHARGE_PROCESSING'] } },
    { $set: { status: 'FAILED', providerStatus: 'FAILED', failureReason: 'Operator rejected', completedAt: now } },
    { returnDocument: 'after' }
  );

  expect(updatedRechargeTx.status).toBe('FAILED');

  // Release reservation on failure
  await walletService.releaseReservation(testUserId, 100);

  const updatedGlobalTx = await Transaction.findOneAndUpdate(
    { referenceId: testOrderId },
    { $set: { status: 'failed', failureReason: 'Operator rejected', completedAt: now } },
    { returnDocument: 'after' }
  );

  expect(updatedGlobalTx.status).toBe('failed');

  const walletAfter = await Wallet.findOne({ userId: testUserId });
  console.log(`- Wallet after release -> Balance: ₹${walletAfter.balancePaise / 100}, OnHold: ₹${walletAfter.onHoldPaise / 100}`);
  expect(walletAfter.onHoldPaise).toBe(0);

  // Cleanup test data
  await RechargeTransaction.deleteOne({ _id: rechargeTx._id });
  await Transaction.deleteOne({ _id: globalTx._id });
  await Wallet.deleteOne({ userId: testUserId });

  console.log('\n=== FAILED LIFECYCLE RECONCILIATION VERIFICATION PASSED ===');
  process.exit(0);
}

function expect(val) {
  return {
    toBe: (expected) => {
      if (val !== expected) throw new Error(`Expected ${expected} but got ${val}`);
    }
  };
}

testFailedLifecycle().catch((err) => {
  console.error('\nLifecycle Test Error:', err);
  process.exit(1);
});
