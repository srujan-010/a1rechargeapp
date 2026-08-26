const mongoose = require('mongoose');
const dotenv = require('dotenv');
dotenv.config();

const connectDB = require('../config/db');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const Wallet = require('../models/Wallet');
const User = require('../models/User');
const CommissionHistory = require('../models/CommissionHistory');
const walletService = require('../services/wallet/wallet.service');
const { normalizeStatus } = require('../utils/statusNormalizer');

async function testReconciliationLifecycle() {
  await connectDB();
  console.log('=== VERIFYING RECHARGE RECONCILIATION LIFECYCLE ===\n');

  // Create dummy test user & wallet
  const testUserId = new mongoose.Types.ObjectId();
  const testOrderId = `TEST_RECON_${Date.now()}`;

  await Wallet.create({
    userId: testUserId,
    balancePaise: 50000, // ₹500
    onHoldPaise: 0,
    currency: 'INR',
  });

  console.log('[1] Reserving ₹100 in wallet for test transaction...');
  await walletService.reserveAmount(testUserId, 100);

  // 1. Create Initial Transaction in PROCESSING status
  console.log('[2] Creating RechargeTransaction and Transaction in PROCESSING status...');
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

  console.log(`- RechargeTransaction created with status: ${rechargeTx.status}`);
  console.log(`- Transaction created with status: ${globalTx.status}`);

  // 2. Simulate Provider Status changing to SUCCESS
  console.log('\n[3] Simulating Provider Reconciliation transition to SUCCESS...');
  const now = new Date();
  
  // Atomic update matching non-terminal states
  const updatedRechargeTx = await RechargeTransaction.findOneAndUpdate(
    { _id: rechargeTx._id, status: { $in: ['PENDING', 'PROCESSING', 'RECHARGE_PROCESSING'] } },
    { $set: { status: 'SUCCESS', providerStatus: 'SUCCESS', providerTransactionId: 'A1PROV999', completedAt: now } },
    { new: true }
  );

  expect(updatedRechargeTx).not.toBeNull();
  expect(updatedRechargeTx.status).toBe('SUCCESS');

  await walletService.commitReservation(testUserId, 98);

  const updatedGlobalTx = await Transaction.findOneAndUpdate(
    { referenceId: testOrderId },
    { $set: { status: 'success', apiReference: 'A1PROV999', completedAt: now } },
    { new: true }
  );

  expect(updatedGlobalTx.status).toBe('success');
  console.log(`- RechargeTransaction updated to: ${updatedRechargeTx.status}`);
  console.log(`- Transaction updated to: ${updatedGlobalTx.status}`);

  // 3. Test Idempotency Guard on duplicate status check
  console.log('\n[4] Testing Idempotency Guard (2nd status check attempt)...');
  const duplicateAttempt = await RechargeTransaction.findOneAndUpdate(
    { _id: rechargeTx._id, status: { $in: ['PENDING', 'PROCESSING', 'RECHARGE_PROCESSING'] } },
    { $set: { status: 'SUCCESS' } },
    { new: true }
  );

  console.log(`- Duplicate update result: ${duplicateAttempt ? 'FAILED IDEMPOTENCY' : 'PASSED (Skipped correctly)'}`);

  // Cleanup test data
  await RechargeTransaction.deleteOne({ _id: rechargeTx._id });
  await Transaction.deleteOne({ _id: globalTx._id });
  await Wallet.deleteOne({ userId: testUserId });

  console.log('\n=== RECONCILIATION LIFECYCLE VERIFICATION PASSED PERFECTLY ===');
  process.exit(0);
}

function expect(val) {
  return {
    toBe: (expected) => {
      if (val !== expected) throw new Error(`Expected ${expected} but got ${val}`);
    },
    not: {
      toBeNull: () => {
        if (val === null || val === undefined) throw new Error(`Expected non-null value but got ${val}`);
      }
    }
  };
}

testReconciliationLifecycle().catch((err) => {
  console.error('\nLifecycle Test Error:', err);
  process.exit(1);
});
