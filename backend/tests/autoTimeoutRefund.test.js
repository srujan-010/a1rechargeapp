const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const Notification = require('../models/Notification');
const CommissionHistory = require('../models/CommissionHistory');
const Wallet = require('../models/Wallet');
const User = require('../models/User');
const autoTimeoutRefundService = require('../services/autoTimeoutRefund.service');

const TEST_PREFIX = 'TEST_AUTO_TIMEOUT_';

beforeAll(async () => {
  if (mongoose.connection.readyState === 0) {
    await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  }
});

afterAll(async () => {
  await RechargeTransaction.deleteMany({ orderId: new RegExp(`^${TEST_PREFIX}`) });
  await Transaction.deleteMany({ referenceId: new RegExp(`^${TEST_PREFIX}`) });
  await Notification.deleteMany({ relatedOrderId: new RegExp(`^${TEST_PREFIX}`) });
  await CommissionHistory.deleteMany({ orderId: new RegExp(`^${TEST_PREFIX}`) });
  await User.deleteMany({ retailerId: new RegExp(`^${TEST_PREFIX}`) });
  await mongoose.disconnect();
});

beforeEach(async () => {
  await RechargeTransaction.deleteMany({ orderId: new RegExp(`^${TEST_PREFIX}`) });
  await Transaction.deleteMany({ referenceId: new RegExp(`^${TEST_PREFIX}`) });
  await Notification.deleteMany({ relatedOrderId: new RegExp(`^${TEST_PREFIX}`) });
  await CommissionHistory.deleteMany({ orderId: new RegExp(`^${TEST_PREFIX}`) });
  await User.deleteMany({ retailerId: new RegExp(`^${TEST_PREFIX}`) });
});

describe('Auto-Timeout and Refund Service Tests', () => {
  test('TEST 1: Transaction with age 10 minutes remains PROCESSING and is NOT refunded', async () => {
    const user = await User.create({
      retailerId: `${TEST_PREFIX}U1`,
      name: 'Test Personal',
      phone: '9990001001',
      accountType: 'PERSONAL',
    });

    const tenMinsAgo = new Date(Date.now() - 10 * 60 * 1000);
    const txn = await RechargeTransaction.create({
      orderId: `${TEST_PREFIX}10MIN`,
      userId: user._id,
      mobileNumber: '9990001001',
      operatorCode: 'AT',
      circleCode: '90',
      amount: 10,
      payableAmount: 10,
      status: 'PROCESSING',
      paymentMethod: 'WALLET',
      accountType: 'PERSONAL',
      createdAt: tenMinsAgo,
    });

    const res = await autoTimeoutRefundService.processSingleTransaction(txn);
    expect(res.status).toBe('ALREADY_TERMINAL');

    const checkDoc = await RechargeTransaction.findById(txn._id);
    expect(checkDoc.status).toBe('PROCESSING');
    expect(checkDoc.refundStatus).toBe('NONE');
  });

  test('TEST 2: Transaction with age 29 minutes remains PENDING and is NOT refunded', async () => {
    const user = await User.create({
      retailerId: `${TEST_PREFIX}U2`,
      name: 'Test Retailer',
      phone: '9990001002',
      accountType: 'RETAILER',
    });

    const twentyNineMinsAgo = new Date(Date.now() - 29 * 60 * 1000);
    const txn = await RechargeTransaction.create({
      orderId: `${TEST_PREFIX}29MIN`,
      userId: user._id,
      mobileNumber: '9990001002',
      operatorCode: 'AT',
      circleCode: '90',
      amount: 50,
      payableAmount: 49,
      status: 'PENDING',
      paymentMethod: 'WALLET',
      accountType: 'RETAILER',
      createdAt: twentyNineMinsAgo,
    });

    const res = await autoTimeoutRefundService.processSingleTransaction(txn);
    expect(res.status).toBe('ALREADY_TERMINAL');

    const checkDoc = await RechargeTransaction.findById(txn._id);
    expect(checkDoc.status).toBe('PENDING');
  });

  test('TEST 3: Transaction with age 31 minutes is marked FAILED and refunded', async () => {
    const user = await User.create({
      retailerId: `${TEST_PREFIX}U3`,
      name: 'Personal User',
      phone: '9990001003',
      accountType: 'PERSONAL',
    });
    await Wallet.create({ userId: user._id, balancePaise: 5000, onHoldPaise: 1000 });

    const thirtyOneMinsAgo = new Date(Date.now() - 31 * 60 * 1000);
    const txn = await RechargeTransaction.create({
      orderId: `${TEST_PREFIX}31MIN`,
      userId: user._id,
      mobileNumber: '9990001003',
      operatorCode: 'AT',
      circleCode: '90',
      amount: 10,
      payableAmount: 10,
      reservedAmount: 10,
      status: 'PENDING',
      paymentMethod: 'WALLET',
      accountType: 'PERSONAL',
      createdAt: thirtyOneMinsAgo,
    });

    await Transaction.create({
      referenceId: `${TEST_PREFIX}31MIN`,
      userId: user._id,
      amountPaise: 1000,
      status: 'pending',
      service: 'mobile_recharge',
      type: 'debit',
    });

    const res = await autoTimeoutRefundService.processSingleTransaction(txn, new Date(), new Date(Date.now() - 30 * 60 * 1000));
    expect(res.status).toBe('SUCCESS');
    expect(res.refundStatus).toBe('REFUNDED');

    const checkDoc = await RechargeTransaction.findById(txn._id);
    expect(checkDoc.status).toBe('FAILED');
    expect(checkDoc.failureReason).toContain('timed out after 30 minutes');
    expect(checkDoc.refundStatus).toBe('REFUNDED');
    expect(checkDoc.refundAmount).toBe(10);
    expect(checkDoc.refundReference).toBe(`REFUND-${TEST_PREFIX}31MIN`);

    const globalTxn = await Transaction.findOne({ referenceId: `${TEST_PREFIX}31MIN` });
    expect(globalTxn.status).toBe('failed');

    const notif = await Notification.findOne({ relatedOrderId: `${TEST_PREFIX}31MIN` });
    expect(notif).toBeTruthy();
    expect(notif.notificationType).toBe('RECHARGE_FAILED');
  });

  test('TEST 4: Running again does NOT cause duplicate refund or notification', async () => {
    const user = await User.create({
      retailerId: `${TEST_PREFIX}U4`,
      name: 'User 4',
      phone: '9990001004',
      accountType: 'PERSONAL',
    });
    await Wallet.create({ userId: user._id, balancePaise: 5000 });

    const fortyMinsAgo = new Date(Date.now() - 40 * 60 * 1000);
    const txn = await RechargeTransaction.create({
      orderId: `${TEST_PREFIX}DUPLICATE`,
      userId: user._id,
      mobileNumber: '9990001004',
      operatorCode: 'VI',
      circleCode: '90',
      amount: 20,
      payableAmount: 20,
      status: 'PROCESSING',
      paymentMethod: 'WALLET',
      createdAt: fortyMinsAgo,
    });

    const cutoff = new Date(Date.now() - 30 * 60 * 1000);

    // Run cycle 1
    const res1 = await autoTimeoutRefundService.processSingleTransaction(txn, new Date(), cutoff);
    expect(res1.status).toBe('SUCCESS');

    // Run cycle 2
    const res2 = await autoTimeoutRefundService.processSingleTransaction(txn, new Date(), cutoff);
    expect(res2.status).toBe('ALREADY_TERMINAL');

    const notifCount = await Notification.countDocuments({ relatedOrderId: `${TEST_PREFIX}DUPLICATE` });
    expect(notifCount).toBe(1);
  });

  test('TEST 5: Transaction already SUCCESS is never modified or refunded', async () => {
    const user = await User.create({
      retailerId: `${TEST_PREFIX}U5`,
      name: 'Success User',
      phone: '9990001005',
      accountType: 'RETAILER',
    });

    const twoHoursAgo = new Date(Date.now() - 120 * 60 * 1000);
    const txn = await RechargeTransaction.create({
      orderId: `${TEST_PREFIX}SUCCESS_OLD`,
      userId: user._id,
      mobileNumber: '9990001005',
      operatorCode: 'AT',
      circleCode: '90',
      amount: 10,
      payableAmount: 10,
      status: 'SUCCESS',
      createdAt: twoHoursAgo,
    });

    const res = await autoTimeoutRefundService.processSingleTransaction(txn, new Date(), new Date(Date.now() - 30 * 60 * 1000));
    expect(res.status).toBe('ALREADY_TERMINAL');

    const checkDoc = await RechargeTransaction.findById(txn._id);
    expect(checkDoc.status).toBe('SUCCESS');
    expect(checkDoc.refundStatus).toBe('NONE');
  });

  test('TEST 6: Abandoned Razorpay payment is failed with NOT_APPLICABLE refundStatus', async () => {
    const user = await User.create({
      retailerId: `${TEST_PREFIX}U6`,
      name: 'Abandoned User',
      phone: '9990001006',
    });
    const fortyMinsAgo = new Date(Date.now() - 40 * 60 * 1000);

    const txn = await RechargeTransaction.create({
      orderId: `${TEST_PREFIX}ABANDONED_RZP`,
      userId: user._id,
      mobileNumber: '9990001006',
      operatorCode: 'AT',
      circleCode: '90',
      amount: 10,
      payableAmount: 10,
      status: 'PAYMENT_PENDING',
      paymentMethod: 'RAZORPAY_UPI',
      razorpayPaymentId: null,
      createdAt: fortyMinsAgo,
    });

    const res = await autoTimeoutRefundService.processSingleTransaction(txn, new Date(), new Date(Date.now() - 30 * 60 * 1000));
    expect(res.status).toBe('SUCCESS');
    expect(res.refundStatus).toBe('NOT_APPLICABLE');

    const checkDoc = await RechargeTransaction.findById(txn._id);
    expect(checkDoc.status).toBe('FAILED');
    expect(checkDoc.refundStatus).toBe('NOT_APPLICABLE');
    expect(checkDoc.refundAmount).toBe(0);
  });
});
