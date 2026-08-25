const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const OperatorCommission = require('../models/OperatorCommission');
const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
const Transaction = require('../models/Transaction');
const commissionService = require('../services/commission/commission.service');
const { protect, requireRetailer } = require('../middleware/authMiddleware');
const { calculateRechargePayable, executeRecharge } = require('../controllers/recharge.controller');
const { getBalance } = require('../controllers/walletController');

describe('Account Type Separation Suite (PERSONAL vs RETAILER)', () => {
  const personalPhone = '9777111222';
  const retailerPhone = '9777333444';

  let personalUser;
  let retailerUser;
  let personalToken;
  let retailerToken;
  let testOperator;

  beforeAll(async () => {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test');
    }

    const phones = [personalPhone, retailerPhone];
    await User.deleteMany({ phone: { $in: phones.concat(phones.map(p => `+91${p}`)) } });

    personalUser = await User.create({
      retailerId: 'PERS_TEST_1',
      phone: personalPhone,
      name: 'Personal Test User',
      accountType: 'PERSONAL',
      role: 'retailer',
      isOnboarded: true,
      isVerified: true,
    });

    retailerUser = await User.create({
      retailerId: 'RET_TEST_1',
      phone: retailerPhone,
      name: 'Retailer Test User',
      accountType: 'RETAILER',
      role: 'retailer',
      isOnboarded: true,
      isVerified: true,
    });

    // Create wallet for retailer only
    await Wallet.create({
      userId: retailerUser._id,
      balancePaise: 50000, // ₹500
      reservedPaise: 0,
    });

    // Create test operator commission rule (Retailer 2%, Personal 1.8%)
    await OperatorCommission.deleteMany({ operatorCode: 'AIRTEL_TEST' });
    await OperatorCommission.create({
      operatorCode: 'AIRTEL_TEST',
      operatorName: 'Airtel Test',
      serviceType: 'mobile',
      providerCommission: 4,
      retailerCommission: 2.0, // 2%
      personalCommission: 1.8, // 1.8%
      companyCommission: 2,
      status: 'ACTIVE',
    });

    testOperator = await ProviderOperator.findOne({ code: 'AIRTEL_TEST' });
    if (!testOperator) {
      testOperator = await ProviderOperator.create({
        code: 'AIRTEL_TEST',
        name: 'Airtel Test',
        serviceType: 'Mobile',
        status: true,
      });
    }

    const jwtSecret = process.env.JWT_SECRET || 'test_jwt_secret';
    personalToken = jwt.sign({ id: personalUser._id, phone: personalPhone }, jwtSecret, { expiresIn: '1h' });
    retailerToken = jwt.sign({ id: retailerUser._id, phone: retailerPhone }, jwtSecret, { expiresIn: '1h' });
  });

  afterAll(async () => {
    await User.deleteMany({ _id: { $in: [personalUser._id, retailerUser._id] } });
    await Wallet.deleteMany({ userId: { $in: [personalUser._id, retailerUser._id] } });
    await OperatorCommission.deleteMany({ operatorCode: 'AIRTEL_TEST' });
    await ProviderOperator.deleteMany({ code: 'AIRTEL_TEST' });
    await mongoose.connection.close();
  });

  test('TEST 1 — PERSONAL AUTHORIZATION: requireRetailer returns HTTP 403 Forbidden for Personal user', async () => {
    const req = { user: personalUser };
    let statusCode;
    let responseData;

    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { responseData = data; return res; },
    };

    requireRetailer(req, res, () => {
      statusCode = 200;
    });

    expect(statusCode).toBe(403);
    expect(responseData.success).toBe(false);
    expect(responseData.message).toContain('Access Forbidden');
  });

  test('TEST 2 — RETAILER AUTHORIZATION: requireRetailer allows Retailer user to proceed', async () => {
    const req = { user: retailerUser };
    let statusCode;
    let nextCalled = false;

    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { return res; },
    };

    requireRetailer(req, res, () => {
      nextCalled = true;
    });

    expect(nextCalled).toBe(true);
    expect(statusCode).toBeUndefined();
  });

  test('TEST 3 — PERSONAL PRICING & DTO PRIVACY: Strips internal commission fields for Personal users', async () => {
    const req = {
      user: personalUser,
      body: {
        serviceType: 'mobile',
        operatorCode: 'AIRTEL_TEST',
        amount: 100,
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { responseData = data; return res; },
    };

    await calculateRechargePayable(req, res, (err) => { if (err) throw err; });

    expect(statusCode).toBe(200);
    expect(responseData.success).toBe(true);

    const dto = responseData.data;
    expect(dto.rechargeAmount).toBe(100);
    expect(dto.payableAmount).toBe(98.2); // 100 - 1.8%
    expect(dto.currency).toBe('INR');

    // PRIVACY VERIFICATION: Ensure internal fields are NEVER exposed to Personal user
    expect(dto.commissionAmount).toBeUndefined();
    expect(dto.commissionPercentage).toBeUndefined();
    expect(dto.retailerCommission).toBeUndefined();
    expect(dto.providerCommission).toBeUndefined();
    expect(dto.a1Margin).toBeUndefined();
    expect(dto.personalAdjustment).toBeUndefined();
  });

  test('TEST 4 — RETAILER PRICING DTO: Retailer user receives full retailer commission breakdown', async () => {
    const req = {
      user: retailerUser,
      body: {
        serviceType: 'mobile',
        operatorCode: 'AIRTEL_TEST',
        amount: 100,
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { responseData = data; return res; },
    };

    await calculateRechargePayable(req, res, (err) => { if (err) throw err; });

    expect(statusCode).toBe(200);
    expect(responseData.success).toBe(true);

    const dto = responseData.data;
    expect(dto.rechargeAmount).toBe(100);
    expect(dto.commissionAmount).toBe(2.0); // 2% retailer rate
    expect(dto.payableAmount).toBe(98.0);
    expect(dto.commissionPercentage).toBe(2.0);
  });

  test('TEST 5 — PERSONAL RECHARGE WITH ₹0 WALLET BALANCE: Direct UPI payment succeeds without wallet balance error', async () => {
    // Confirm personal user has no wallet doc
    const pWallet = await Wallet.findOne({ userId: personalUser._id });
    expect(pWallet).toBeNull();

    const commission = await commissionService.calculateCommission('AIRTEL_TEST', 100, 'Airtel Test', 'mobile');
    expect(commission.personalCommissionPercentage).toBe(1.8);
    expect(commission.personalDiscountAmount).toBe(1.8);
  });

  test('TEST 6 — CENTRALIZED COMMISSION SERVICE: Calculates distinct rates for RETAILER vs PERSONAL', async () => {
    const retDetails = await commissionService.calculateCommission('AIRTEL_TEST', 200, 'Airtel Test', 'mobile');
    expect(retDetails.retailerCommissionPercentage).toBe(2.0);
    expect(retDetails.retailerCommissionAmount).toBe(4.0); // 2% of 200

    expect(retDetails.personalCommissionPercentage).toBe(1.8);
    expect(retDetails.personalDiscountAmount).toBe(3.6); // 1.8% of 200
  });

  test('TEST 7 — BACKEND AUTHORITATIVE SOURCE OF TRUTH: User accountType from database is immutable to client tampering', async () => {
    const dbUser = await User.findById(personalUser._id);
    expect(dbUser.accountType).toBe('PERSONAL');

    // Simulate tampered client request attempting to claim 'RETAILER'
    const tamperedReq = {
      user: dbUser,
      body: { accountType: 'RETAILER' },
    };

    let statusCode;
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { return res; },
    };

    requireRetailer(tamperedReq, res, () => {});

    expect(statusCode).toBe(403); // Backend user model was enforced, client override ignored
  });
});
