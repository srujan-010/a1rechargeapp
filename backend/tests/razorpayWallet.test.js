const mongoose = require('mongoose');
const crypto = require('crypto');
const path = require('path');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const Transaction = require('../models/Transaction');
const WalletFundingTransaction = require('../models/WalletFundingTransaction');
const { createOrder, verifyPayment, handleWebhook } = require('../controllers/razorpayWalletController');
const { getDashboardSummary } = require('../controllers/walletController');
const connectDB = require('../config/db');

require('dotenv').config({ path: path.join(__dirname, '../.env') });

describe('Razorpay Checkout Wallet Funding Integration Tests', () => {
  let retailerUser;
  let mockRes;
  let mockNext;

  beforeAll(async () => {
    jest.setTimeout(30000);
    await connectDB();
  });

  afterAll(async () => {
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    process.env.WALLET_FUNDING_MODE = 'RAZORPAY';
    process.env.RAZORPAY_KEY_ID = 'rzp_live_TT5zU7nK3KcH8Y';
    process.env.RAZORPAY_KEY_SECRET = 'test_secret_key_12345';
    process.env.RAZORPAY_WEBHOOK_SECRET = 'test_webhook_secret_67890';

    await User.deleteMany({ phone: '9888877777' });
    await Wallet.deleteMany({});
    await WalletLedger.deleteMany({});
    await Transaction.deleteMany({});
    await WalletFundingTransaction.deleteMany({});

    retailerUser = await User.create({
      name: 'Test Retailer',
      phone: '9888877777',
      retailerId: 'RET98888',
      role: 'retailer',
    });

    // Initial wallet balance: ₹500.00 (50000 paise)
    await Wallet.create({
      userId: retailerUser._id,
      balancePaise: 50000,
      onHoldPaise: 0,
    });

    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    mockNext = jest.fn();
  });

  test('1. Backend creates Razorpay order & stores internal transaction (Wallet unchanged)', async () => {
    const req = {
      user: retailerUser,
      body: { amountPaise: 100000 }, // ₹1,000
    };

    await createOrder(req, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    const resData = mockRes.json.mock.calls[0][0];
    expect(resData.success).toBe(true);
    expect(resData.data.amountRupees).toBe(1000);
    expect(resData.data.razorpayKeyId).toBe('rzp_live_TT5zU7nK3KcH8Y');
    expect(resData.data.internalTransactionId).toMatch(/^WFT_/);

    // Verify DB record created in PENDING/CREATED state
    const wft = await WalletFundingTransaction.findOne({ internalTransactionId: resData.data.internalTransactionId });
    expect(wft).not.toBeNull();
    expect(wft.amountPaise).toBe(100000);

    // CRITICAL: Wallet balance MUST remain ₹500.00 at order creation!
    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(50000);
  });

  test('2. Backend verifies HMAC signature & credits wallet atomically with ledger', async () => {
    // Step A: Create Order
    const createReq = { user: retailerUser, body: { amountPaise: 100000 } };
    await createOrder(createReq, mockRes, mockNext);
    const orderData = mockRes.json.mock.calls[0][0].data;

    const internalTransactionId = orderData.internalTransactionId;
    const razorpayOrderId = orderData.razorpayOrderId;
    const razorpayPaymentId = `pay_test_${Date.now()}`;

    // Step B: Compute valid HMAC signature
    const razorpaySignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    const verifyReq = {
      user: retailerUser,
      body: {
        internalTransactionId,
        razorpayOrderId,
        razorpayPaymentId,
        razorpaySignature,
      },
    };

    const mockResVerify = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    await verifyPayment(verifyReq, mockResVerify, mockNext);

    expect(mockResVerify.status).toHaveBeenCalledWith(200);
    const verifyData = mockResVerify.json.mock.calls[0][0];
    expect(verifyData.success).toBe(true);
    expect(verifyData.data.previousBalanceRupees).toBe(500);
    expect(verifyData.data.newBalanceRupees).toBe(1500); // ₹500 + ₹1000 = ₹1500

    // Verify Wallet Balance in DB
    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(150000); // ₹1,500.00

    // Verify Wallet Ledger Record
    const ledger = await WalletLedger.findOne({ referenceId: internalTransactionId });
    expect(ledger).not.toBeNull();
    expect(ledger.referenceType).toBe('RAZORPAY_WALLET_CREDIT');
    expect(ledger.amount).toBe(1000);
    expect(ledger.previousBalance).toBe(500);
    expect(ledger.balanceAfter).toBe(1500);

    // Verify Statement Transaction
    const tx = await Transaction.findOne({ referenceId: internalTransactionId });
    expect(tx).not.toBeNull();
    expect(tx.service).toBe('wallet_topup');
    expect(tx.paymentMethod).toBe('razorpay');
    expect(tx.closingBalancePaise).toBe(150000);
  });

  test('3. Idempotency Check: Re-submitting payment verification does NOT double credit', async () => {
    const createReq = { user: retailerUser, body: { amountPaise: 100000 } };
    await createOrder(createReq, mockRes, mockNext);
    const orderData = mockRes.json.mock.calls[0][0].data;

    const internalTransactionId = orderData.internalTransactionId;
    const razorpayOrderId = orderData.razorpayOrderId;
    const razorpayPaymentId = `pay_idem_${Date.now()}`;
    const razorpaySignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    const verifyReq = {
      user: retailerUser,
      body: { internalTransactionId, razorpayOrderId, razorpayPaymentId, razorpaySignature },
    };

    // First Verification
    const mockRes1 = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    await verifyPayment(verifyReq, mockRes1, mockNext);

    let wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(150000); // ₹1500

    // Second Verification (Simulating retry/double-click)
    const mockRes2 = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    await verifyPayment(verifyReq, mockRes2, mockNext);

    expect(mockRes2.status).toHaveBeenCalledWith(200);
    const res2Data = mockRes2.json.mock.calls[0][0];
    expect(res2Data.success).toBe(true);
    expect(res2Data.data.isDuplicate).toBe(true);

    // Balance MUST remain ₹1,500.00 (NOT ₹2,500.00!)
    wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(150000);
  });

  test('4. Tampered signature is rejected and wallet balance is NOT modified', async () => {
    const createReq = { user: retailerUser, body: { amountPaise: 100000 } };
    await createOrder(createReq, mockRes, mockNext);
    const orderData = mockRes.json.mock.calls[0][0].data;

    const verifyReq = {
      user: retailerUser,
      body: {
        internalTransactionId: orderData.internalTransactionId,
        razorpayOrderId: orderData.razorpayOrderId,
        razorpayPaymentId: 'pay_tampered_123',
        razorpaySignature: 'invalid_tampered_signature_string',
      },
    };

    // Force non-test mode check for signature failure simulation
    const origEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';

    const mockResFail = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    await verifyPayment(verifyReq, mockResFail, mockNext);

    process.env.NODE_ENV = origEnv;

    expect(mockResFail.status).toHaveBeenCalledWith(400);
    const resData = mockResFail.json.mock.calls[0][0];
    expect(resData.success).toBe(false);
    expect(resData.code).toBe('INVALID_SIGNATURE');

    // Balance remains ₹500.00
    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(50000);
  });

  test('5. Webhook handles payment.captured event idempotently', async () => {
    const createReq = { user: retailerUser, body: { amountPaise: 100000 } };
    await createOrder(createReq, mockRes, mockNext);
    const orderData = mockRes.json.mock.calls[0][0].data;

    const webhookBody = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_webhook_123',
            order_id: orderData.razorpayOrderId,
            amount: 100000,
            currency: 'INR',
          },
        },
      },
    };

    const bodyStr = JSON.stringify(webhookBody);
    const signature = crypto
      .createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET)
      .update(bodyStr)
      .digest('hex');

    const webhookReq = {
      headers: { 'x-razorpay-signature': signature },
      body: webhookBody,
    };

    const mockResWh = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    await handleWebhook(webhookReq, mockResWh, mockNext);

    expect(mockResWh.status).toHaveBeenCalledWith(200);

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(150000);
  });

  test('6. Wallet topup funding is excluded from Today\'s Recharge statistics', async () => {
    // Add a Razorpay wallet topup transaction
    await Transaction.create({
      userId: retailerUser._id,
      type: 'credit',
      amountPaise: 100000,
      status: 'success',
      service: 'wallet_topup',
      paymentMethod: 'razorpay',
      referenceId: 'WFT_STATS_123',
      closingBalancePaise: 150000,
      createdAt: new Date(),
    });

    const req = { user: retailerUser };
    await getDashboardSummary(req, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    const summary = mockRes.json.mock.calls[0][0].data;

    expect(summary.todayRechargeAmount).toBe(0);
    expect(summary.todayTransactions).toBe(0);
  });
});
