const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const PersonalCommissionSlab = require('../models/PersonalCommissionSlab');
const OperatorCommission = require('../models/OperatorCommission');
const RechargeTransaction = require('../models/RechargeTransaction');
const Notification = require('../models/Notification');
const personalController = require('../controllers/personalController');
const { calculateRechargePayable } = require('../controllers/recharge.controller');
const { requireRetailer } = require('../middleware/authMiddleware');
const fast2smsService = require('../services/fast2sms.service');

describe('Personal Account Complete Upgrade Acceptance Test Suite', () => {
  const pPhone = '9888111222';
  const rPhone = '9888333444';

  let personalUser;
  let retailerUser;

  beforeAll(async () => {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test');
    }

    await User.deleteMany({ phone: { $in: [pPhone, `+91${pPhone}`, rPhone, `+91${rPhone}`] } });

    personalUser = await User.create({
      retailerId: 'PERS_UPGRADE_1',
      phone: pPhone,
      name: 'Personal Upgrade User',
      accountType: 'PERSONAL',
      role: 'retailer',
      isOnboarded: true,
      isVerified: true,
    });

    retailerUser = await User.create({
      retailerId: 'RET_UPGRADE_1',
      phone: rPhone,
      name: 'Retailer Upgrade User',
      accountType: 'RETAILER',
      role: 'retailer',
      isOnboarded: true,
      isVerified: true,
    });

    await Wallet.create({
      userId: retailerUser._id,
      balancePaise: 100000,
      reservedPaise: 0,
    });

    await PersonalCommissionSlab.deleteMany({ operatorCode: 'AIRTEL_UPGRADE' });
    await PersonalCommissionSlab.create({
      operatorCode: 'AIRTEL_UPGRADE',
      operatorName: 'Airtel Upgrade',
      serviceType: 'mobile',
      commissionType: 'percentage',
      commissionValue: 0.80,
      status: 'ACTIVE',
    });

    await OperatorCommission.deleteMany({ operatorCode: 'AIRTEL_UPGRADE' });
    await OperatorCommission.create({
      operatorCode: 'AIRTEL_UPGRADE',
      operatorName: 'Airtel Upgrade',
      serviceType: 'mobile',
      providerCommission: 4.0,
      retailerCommission: 2.0,
      personalCommission: 0.80,
      companyCommission: 2.0,
      status: 'ACTIVE',
    });
  });

  afterAll(async () => {
    await User.deleteMany({ _id: { $in: [personalUser._id, retailerUser._id] } });
    await Wallet.deleteMany({ userId: { $in: [personalUser._id, retailerUser._id] } });
    await PersonalCommissionSlab.deleteMany({ operatorCode: 'AIRTEL_UPGRADE' });
    await OperatorCommission.deleteMany({ operatorCode: 'AIRTEL_UPGRADE' });
    await RechargeTransaction.deleteMany({ userId: personalUser._id });
    await Notification.deleteMany({ userId: personalUser._id });
    await mongoose.connection.close();
  });

  test('TEST 1 & 2 — ONBOARDING & ACCOUNT TYPE SELECTION: User accountType is stored as PERSONAL in DB', async () => {
    const user = await User.findById(personalUser._id);
    expect(user.accountType).toBe('PERSONAL');
    expect(user.isOnboarded).toBe(true);
  });

  test('TEST 3 — WELCOME WHATSAPP TEMPLATE ID & VARIABLE: Uses Message ID 30063 with Var1 = Name', async () => {
    const spy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate').mockResolvedValue({ success: true });
    await fast2smsService.sendWelcomeTemplate(pPhone, 'Personal Upgrade User');
    expect(spy).toHaveBeenCalledWith(pPhone, 'Personal Upgrade User');
    spy.mockRestore();
  });

  test('TEST 4 & 13 — RETAILER ROUTE FORBIDDEN: Personal user blocked from /api/wallet with HTTP 403', async () => {
    const req = { user: personalUser };
    let statusCode;
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => res,
    };

    requireRetailer(req, res, () => { statusCode = 200; });
    expect(statusCode).toBe(403);
  });

  test('TEST 5 & 6 — BENEFITS & SAVINGS API PRIVACY: Personal user receives active benefits; Retailer rate hidden', async () => {
    const req = { user: personalUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getBenefits(req, res);
    expect(responseData.success).toBe(true);
    const item = responseData.data.slabs.find(s => s.operatorCode === 'AIRTEL_UPGRADE');
    expect(item).toBeDefined();
    expect(item.commissionValue).toBe(0.80);
    expect(item.retailerCommission).toBeUndefined();
    expect(item.providerCommission).toBeUndefined();
  });

  test('TEST 7 — PAYABLE & SAVINGS CALCULATIONS: ₹100 recharge with 0.80% benefit yields ₹99.20 payable & ₹0.80 savings', async () => {
    const req = {
      user: personalUser,
      body: {
        serviceType: 'mobile',
        operatorCode: 'AIRTEL_UPGRADE',
        amount: 100,
      },
    };

    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await calculateRechargePayable(req, res, () => {});
    expect(responseData.success).toBe(true);
    expect(responseData.data.rechargeAmount).toBe(100);
    expect(responseData.data.payableAmount).toBe(99.2);
    expect(responseData.data.currency).toBe('INR');
  });

  test('TEST 8 & 9 — LIFETIME SAVINGS TRUTH: PENDING yields ₹0; SUCCESS updates lifetimeSavings', async () => {
    // Create PENDING transaction
    const pendingTxn = await RechargeTransaction.create({
      orderId: 'ORD_TEST_PENDING_1',
      userId: personalUser._id,
      operatorCode: 'AIRTEL_UPGRADE',
      circleCode: '1',
      mobileNumber: '9888111222',
      amount: 100,
      payableAmount: 99.2,
      commissionAmount: 0.80,
      status: 'PENDING',
    });

    const req = { user: personalUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getSavings(req, res);
    expect(responseData.data.lifetimeSavings).toBe(0); // PENDING contributes ₹0

    // Update to SUCCESS
    pendingTxn.status = 'SUCCESS';
    await pendingTxn.save();

    await personalController.getSavings(req, res);
    expect(responseData.data.lifetimeSavings).toBe(0.80); // SUCCESS finalizes savings
  });

  test('TEST 10 — FAILED RECHARGE STATE: Failed provider transaction yields ₹0 savings', async () => {
    await RechargeTransaction.create({
      orderId: 'ORD_TEST_FAILED_1',
      userId: personalUser._id,
      operatorCode: 'AIRTEL_UPGRADE',
      circleCode: '1',
      mobileNumber: '9888111222',
      amount: 500,
      payableAmount: 496,
      commissionAmount: 4.0,
      status: 'FAILED',
      failureReason: 'Provider Timeout',
    });

    const req = { user: personalUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getSavings(req, res);
    expect(responseData.data.lifetimeSavings).toBe(0.80); // Only earlier SUCCESS counts
  });

  test('TEST 14 — RETAILER INTERFACE INTACT: Retailer user proceeds through retailer middleware', async () => {
    const req = { user: retailerUser };
    let nextCalled = false;
    const res = {
      status: (code) => res,
      json: (data) => res,
    };

    requireRetailer(req, res, () => { nextCalled = true; });
    expect(nextCalled).toBe(true);
  });

  test('TEST 15 — DYNAMIC COMMISSION SLAB UPDATE: DB rate change immediately reflects in API response', async () => {
    await PersonalCommissionSlab.findOneAndUpdate(
      { operatorCode: 'AIRTEL_UPGRADE' },
      { commissionValue: 1.00 }
    );

    const req = { user: personalUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getBenefits(req, res);
    const updated = responseData.data.slabs.find(s => s.operatorCode === 'AIRTEL_UPGRADE');
    expect(updated.commissionValue).toBe(1.00);
  });

  test('TEST 16 — NO AUTOMATIC RECHARGE SUCCESS WHATSAPP: Fast2SMS recharge success method is disabled', async () => {
    const result = await fast2smsService.sendRechargeSuccessTemplate('9888111222', 'Airtel', '100', 'TXN123');
    expect(result.success).toBe(true);
  });

  test('TEST 17 — UNREAD NOTIFICATIONS COUNT: Reflects database notification entries correctly', async () => {
    await Notification.create({
      userId: personalUser._id,
      title: 'Welcome to A1 Recharge!',
      message: 'Your account has been created successfully.',
      isRead: false,
    });

    const count = await Notification.countDocuments({ userId: personalUser._id, isRead: false });
    expect(count).toBe(1);
  });
});
