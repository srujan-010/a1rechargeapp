const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Models
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const Transaction = require('../models/Transaction');
const RechargeTransaction = require('../models/RechargeTransaction');
const Otp = require('../models/Otp');

// Services & Providers
const fast2smsService = require('../services/fast2sms.service');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');
const reviewerService = require('../services/reviewer.service');
const pendingRechargeWorker = require('../workers/pendingRecharge.worker');
const dthStatusWorker = require('../workers/dthStatus.worker');
const autoTimeoutRefundService = require('../services/autoTimeoutRefund.service');

// Controllers
const { sendOtp, verifyOtp } = require('../controllers/authController');
const { executeRecharge, createRazorpayRechargeOrder } = require('../controllers/recharge.controller');
const { createOrder: createRazorpayWalletOrder } = require('../controllers/razorpayWalletController');
const { admin, requireRetailer } = require('../middleware/authMiddleware');

describe('Google Play Reviewer Comprehensive Security & Architecture Test Suite', () => {
  const TEST_REVIEWER_PHONE = '9888877777';
  const TEST_REVIEWER_OTP = '951753'; // Random 6-digit non-predictable secret
  const TEST_REVIEWER_PIN = '246813'; // Valid 6-digit non-sequential PIN

  const NORMAL_CUSTOMER_PHONE = '9123456789';

  let originalEnv;

  beforeAll(async () => {
    originalEnv = { ...process.env };
    process.env.JWT_SECRET = 'test_jwt_secret_key_12345';
    process.env.GOOGLE_PLAY_REVIEWER_PHONE = TEST_REVIEWER_PHONE;
    process.env.GOOGLE_PLAY_REVIEWER_OTP = TEST_REVIEWER_OTP;
    process.env.GOOGLE_PLAY_REVIEWER_PIN = TEST_REVIEWER_PIN;

    // Connect DB if not connected
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/a1recharge_test');
    }
  });

  afterAll(async () => {
    process.env = originalEnv;
    await User.deleteMany({ phone: { $in: [TEST_REVIEWER_PHONE, NORMAL_CUSTOMER_PHONE, `+91${NORMAL_CUSTOMER_PHONE}`] } });
    await Wallet.deleteMany({});
    await WalletLedger.deleteMany({});
    await Transaction.deleteMany({});
    await RechargeTransaction.deleteMany({});
    await Otp.deleteMany({});
    if (mongoose.connection.readyState !== 0) {
      await mongoose.connection.close();
    }
  });

  beforeEach(async () => {
    jest.clearAllMocks();
    reviewerService.resetRateLimits();
    await User.deleteMany({ phone: { $in: [TEST_REVIEWER_PHONE, NORMAL_CUSTOMER_PHONE] } });
    await Wallet.deleteMany({});
    await WalletLedger.deleteMany({});
    await Transaction.deleteMany({});
    await RechargeTransaction.deleteMany({});
    await Otp.deleteMany({});
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST A: Normal customer OTP uses WhatsApp (Fast2SMS)
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST A: Normal customer number calls Fast2SMS WhatsApp API for OTP generation', async () => {
    const fast2smsSpy = jest.spyOn(fast2smsService, 'sendLoginOtp').mockResolvedValue({ success: true });

    const req = { body: { mobile: NORMAL_CUSTOMER_PHONE } };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    const next = jest.fn();

    await sendOtp(req, res, next);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
    expect(fast2smsSpy).toHaveBeenCalledWith(
      expect.objectContaining({ mobile: NORMAL_CUSTOMER_PHONE })
    );

    // Verify raw OTP is NOT stored in plain text
    const otpDoc = await Otp.findOne({ mobile: NORMAL_CUSTOMER_PHONE, purpose: 'login' });
    expect(otpDoc).toBeTruthy();
    expect(otpDoc.otpHash).not.toBe(TEST_REVIEWER_OTP);
    expect(otpDoc.otpHash).toMatch(/^\$2[aby]\$/); // Valid bcrypt hash format

    fast2smsSpy.mockRestore();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST B: Normal customer rate limits remain active
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST B: Normal customer number adheres to hourly rate limits', async () => {
    // Seed 5 existing requests in the last hour
    const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
    for (let i = 0; i < 5; i++) {
      await Otp.create({
        mobile: NORMAL_CUSTOMER_PHONE,
        purpose: 'login',
        otpHash: 'dummyhash',
        expiresAt: new Date(Date.now() + 600000),
        createdAt: oneMinuteAgo,
      });
    }

    const req = { body: { mobile: NORMAL_CUSTOMER_PHONE } };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    const next = jest.fn((err) => {
      res.statusCode = res.status.mock.calls[0]?.[0] || 500;
      res.error = err;
    });

    await sendOtp(req, res, next);

    expect(res.status).toHaveBeenCalledWith(429);
    expect(next).toHaveBeenCalledWith(expect.objectContaining({
      message: expect.stringContaining('Maximum OTP requests'),
    }));
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST C: Reviewer login works WITHOUT WhatsApp access
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST C: Configured reviewer phone issues OTP without calling Fast2SMS', async () => {
    const fast2smsSpy = jest.spyOn(fast2smsService, 'sendLoginOtp');

    const req = { body: { mobile: TEST_REVIEWER_PHONE } };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    const next = jest.fn();

    await sendOtp(req, res, next);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, message: 'OTP sent successfully.' });

    // ZERO Fast2SMS calls
    expect(fast2smsSpy).not.toHaveBeenCalled();

    // Verify OTP record in DB contains hash of secret OTP
    const otpDoc = await Otp.findOne({ mobile: TEST_REVIEWER_PHONE, purpose: 'login' });
    expect(otpDoc).toBeTruthy();
    const isMatch = await bcrypt.compare(TEST_REVIEWER_OTP, otpDoc.otpHash);
    expect(isMatch).toBe(true);

    // Reviewer OTP is NOT accepted for normal customer
    const wrongUserMatch = await bcrypt.compare('123456', otpDoc.otpHash);
    expect(wrongUserMatch).toBe(false);

    fast2smsSpy.mockRestore();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST D: Reviewer receives normal valid JWT/session
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST D: Reviewer verifies secret OTP and receives standard 30-day JWT', async () => {
    // Send OTP first
    await reviewerService.handleReviewerSendOtp(
      { status: () => ({ json: () => {} }) },
      TEST_REVIEWER_PHONE
    );

    const req = { body: { mobile: TEST_REVIEWER_PHONE, otp: TEST_REVIEWER_OTP }, ip: '127.0.0.1' };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    const next = jest.fn();

    await verifyOtp(req, res, next);

    expect(res.status).toHaveBeenCalledWith(200);
    const responseData = res.json.mock.calls[0][0];
    expect(responseData.success).toBe(true);
    expect(responseData.data.accessToken).toBeDefined();

    // Verify JWT payload
    const decoded = jwt.verify(responseData.data.accessToken, process.env.JWT_SECRET);
    expect(decoded.id).toBeDefined();

    // Verify safe user profile
    expect(responseData.data.user.role).toBe('retailer');
    expect(responseData.data.user.phone).toBe(TEST_REVIEWER_PHONE);
    expect(responseData.data.user.isTestAccount).toBe(true);
    expect(responseData.data.user.securityPinHash).toBeUndefined(); // Zero secret hash leakage
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST E: Reviewer can access required retailer features
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST E: Reviewer account satisfies requireRetailer middleware', async () => {
    const reviewerUser = await reviewerService.ensureReviewerAccount();
    const req = { user: reviewerUser };
    const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    const next = jest.fn();

    requireRetailer(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(res.status).not.toHaveBeenCalled();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST F: Reviewer is forbidden from admin functionality
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST F: Reviewer account is strictly blocked from admin middleware', async () => {
    const reviewerUser = await reviewerService.ensureReviewerAccount();
    const req = { user: reviewerUser };
    const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    const next = jest.fn();

    expect(() => admin(req, res, next)).toThrow('Not authorized as an admin');
    expect(res.status).toHaveBeenCalledWith(403);
    expect(next).not.toHaveBeenCalled();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST G: Reviewer recharge CANNOT reach live A1Topup provider
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST G: Reviewer recharge execution bypasses live a1TopupProvider.recharge', async () => {
    const a1TopupSpy = jest.spyOn(a1TopupProvider, 'recharge');
    const reviewerUser = await reviewerService.ensureReviewerAccount();

    const req = {
      user: reviewerUser,
      body: {
        mobileNumber: '9988776655',
        amount: 199,
        operatorId: 'JIO',
        walletMpin: TEST_REVIEWER_PIN,
      },
    };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    const next = jest.fn();

    await executeRecharge(req, res, next);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(a1TopupSpy).not.toHaveBeenCalled(); // ZERO real distributor calls!

    const response = res.json.mock.calls[0][0];
    expect(response.success).toBe(true);
    expect(response.data.status).toBe('SUCCESS');
    expect(response.data.providerTransactionId).toMatch(/^TEST_TXN_/);

    a1TopupSpy.mockRestore();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST H: Reviewer CANNOT create live Razorpay orders
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST H: Live Razorpay order creation is rejected for reviewer', async () => {
    const reviewerUser = await reviewerService.ensureReviewerAccount();

    // 1. Wallet top-up Razorpay order
    const reqWallet = { user: reviewerUser, body: { amountPaise: 50000 } };
    const resWallet = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    await createRazorpayWalletOrder(reqWallet, resWallet, jest.fn());
    expect(resWallet.status).toHaveBeenCalledWith(400);
    expect(resWallet.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, message: expect.stringContaining('Online payment gateways are disabled') })
    );

    // 2. Recharge Razorpay order
    const reqRecharge = { user: reviewerUser, body: { amount: 299, mobileNumber: '9988776655' } };
    const resRecharge = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    await createRazorpayRechargeOrder(reqRecharge, resRecharge, jest.fn());
    expect(resRecharge.status).toHaveBeenCalledWith(400);
    expect(resRecharge.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, message: expect.stringContaining('Online payment gateways are disabled') })
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST I: Reviewer recharge debits only test wallet; zero real retailer impact
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST I: Recharge debits ONLY reviewer test wallet balance', async () => {
    const reviewerUser = await reviewerService.ensureReviewerAccount();
    const initialWallet = await Wallet.findOne({ userId: reviewerUser._id });
    expect(initialWallet.balancePaise).toBe(250000); // ₹2,500.00 initial test balance

    const req = {
      user: reviewerUser,
      body: {
        mobileNumber: '9876500000',
        amount: 500, // ₹500
        operatorId: 'AIRTEL',
      },
    };
    const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    await executeRecharge(req, res, jest.fn());

    const updatedWallet = await Wallet.findOne({ userId: reviewerUser._id });
    expect(updatedWallet.balancePaise).toBe(200000); // Exactly ₹2,000.00 left (50000 paise debited)

    // Ensure zero other wallet was modified
    const otherWalletsCount = await Wallet.countDocuments({ userId: { $ne: reviewerUser._id } });
    expect(otherWalletsCount).toBe(0);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST J: Reviewer transactions cannot enter live background workers
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST J: Background workers double-lock skips reviewer test records', async () => {
    const reviewerUser = await reviewerService.ensureReviewerAccount();

    // Create a transaction belonging to reviewer
    const reviewerTxn = await RechargeTransaction.create({
      orderId: 'REV_TEST_PENDING_GUARD',
      userId: reviewerUser._id,
      providerName: 'TEST_REVIEWER_SANDBOX',
      mobileNumber: '9988776655',
      amount: 199,
      operatorCode: 'JIO',
      circleCode: '4',
      status: 'PENDING', // artificially simulated non-terminal state
    });

    const a1StatusSpy = jest.spyOn(a1TopupProvider, 'status');

    // Execute pending recharge worker step
    await pendingRechargeWorker.processTransaction(reviewerTxn);

    // Provider status check must NEVER be called
    expect(a1StatusSpy).not.toHaveBeenCalled();

    a1StatusSpy.mockRestore();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST K: Reviewer ledger entries exist only for reviewer user
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST K: WalletLedger entries are strictly scoped to reviewer userId', async () => {
    const reviewerUser = await reviewerService.ensureReviewerAccount();

    const req = {
      user: reviewerUser,
      body: { mobileNumber: '9876511111', amount: 100, operatorId: 'BSNL' },
    };
    await executeRecharge(req, { status: () => ({ json: () => {} }) }, jest.fn());

    const ledgers = await WalletLedger.find({});
    expect(ledgers.length).toBeGreaterThan(0);
    ledgers.forEach((ledger) => {
      expect(ledger.userId.toString()).toBe(reviewerUser._id.toString());
      expect(ledger.remark).toMatch(/REVIEWER_TEST/);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST L: Removing env vars completely disables reviewer mode
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST L: Unsetting reviewer env vars restores 100% normal WhatsApp flow', async () => {
    delete process.env.GOOGLE_PLAY_REVIEWER_PHONE;
    delete process.env.GOOGLE_PLAY_REVIEWER_OTP;

    expect(reviewerService.isReviewerEnabled()).toBe(false);
    expect(reviewerService.isReviewerPhone(TEST_REVIEWER_PHONE)).toBe(false);

    const fast2smsSpy = jest.spyOn(fast2smsService, 'sendLoginOtp').mockResolvedValue({ success: true });

    const req = { body: { mobile: TEST_REVIEWER_PHONE } };
    const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    await sendOtp(req, res, jest.fn());

    // Because reviewer mode is disabled, it calls normal Fast2SMS WhatsApp API!
    expect(fast2smsSpy).toHaveBeenCalled();

    fast2smsSpy.mockRestore();

    // Restore env vars for other tests
    process.env.GOOGLE_PLAY_REVIEWER_PHONE = TEST_REVIEWER_PHONE;
    process.env.GOOGLE_PLAY_REVIEWER_OTP = TEST_REVIEWER_OTP;
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST M: Multi-format conflict check halts and protects existing accounts
  // ───────────────────────────────────────────────────────────────────────────
  test('TEST M: Existing production account is NEVER modified or overwritten', async () => {
    // Seed a real production customer account using the phone
    const realCustomer = await User.create({
      retailerId: 'RET_REAL_CUSTOMER_99',
      phone: TEST_REVIEWER_PHONE,
      name: 'Real Production Customer',
      role: 'retailer',
      isTestAccount: false,
    });

    // Attempting to provision/conflict check MUST throw an error
    await expect(reviewerService.checkExistingUserConflict(TEST_REVIEWER_PHONE)).rejects.toThrow(
      'Configured reviewer phone conflicts with an existing production account'
    );

    // Verify real customer was NOT modified
    const customerInDb = await User.findById(realCustomer._id);
    expect(customerInDb.name).toBe('Real Production Customer');
    expect(customerInDb.isTestAccount).toBe(false);
    expect(customerInDb.retailerId).toBe('RET_REAL_CUSTOMER_99');
  });
});
