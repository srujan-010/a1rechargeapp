const mongoose = require('mongoose');
const User = require('../models/User');
const RechargeTransaction = require('../models/RechargeTransaction');
const UserPlanCache = require('../models/UserPlanCache');
const personalController = require('../controllers/personalController');
const planApiService = require('../services/planapi.service');

describe('Smart Home Card & Daily Plan Cache Acceptance Test Suite', () => {
  const testPhone = '9555111222';
  let testUser;

  beforeAll(async () => {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test');
    }

    await User.deleteMany({ phone: { $in: [testPhone, `+91${testPhone}`] } });
    await RechargeTransaction.deleteMany({ mobileNumber: testPhone });
    await UserPlanCache.deleteMany({ mobileNumber: testPhone });

    testUser = await User.create({
      retailerId: 'SMART_CARD_1',
      phone: testPhone,
      name: 'Smart Card User',
      accountType: 'PERSONAL',
      role: 'retailer',
      isOnboarded: true,
      isVerified: true,
    });
  });

  afterAll(async () => {
    await User.deleteMany({ _id: testUser._id });
    await RechargeTransaction.deleteMany({ userId: testUser._id });
    await UserPlanCache.deleteMany({ userId: testUser._id });
    await mongoose.connection.close();
  });

  test('TEST 1 — BRAND NEW USER: No fake ₹0.00 / PENDING card; returns PLAN_STATUS or NO_PLAN', async () => {
    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.data.amount).toBeUndefined(); // NO fake transaction amount!
    expect(responseData.data.cardType).not.toBe('PENDING'); // NO fake PENDING card!
    expect(['PLAN_STATUS', 'NO_PLAN']).toContain(responseData.data.cardType);
  });

  test('TEST 2 — 24-HOUR DAILY PLAN CACHE: Uses cached UserPlanCache on second call', async () => {
    // Upsert a fresh cache record
    await UserPlanCache.findOneAndUpdate(
      { userId: testUser._id, mobileNumber: testPhone },
      {
        userId: testUser._id,
        mobileNumber: testPhone,
        operatorCode: 'AT',
        operatorName: 'Airtel',
        validity: '28 Days',
        expiryDate: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000), // 10 days in future
        daysRemaining: 10,
        fetchedAt: new Date(),
      },
      { upsert: true, new: true }
    );

    const spy = jest.spyOn(planApiService, 'detectMobileOperator');

    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.data.cardType).toBe('PLAN_STATUS');
    expect(responseData.data.daysRemaining).toBe(10);
    expect(responseData.data.colorState).toBe('GREEN');
    expect(spy).not.toHaveBeenCalled(); // Cache was used, PlansAPI was NOT called!

    spy.mockRestore();
  });

  test('TEST 3 — USER WITH SUCCESSFUL RECHARGE: Transitions Home Card to Last Recharge', async () => {
    await UserPlanCache.deleteMany({ userId: testUser._id });
    await RechargeTransaction.create({
      orderId: 'ORD_SMART_SUCCESS_1',
      userId: testUser._id,
      operatorCode: 'AT',
      circleCode: '1',
      mobileNumber: testPhone,
      amount: 249,
      payableAmount: 247,
      status: 'SUCCESS',
    });

    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.success).toBe(true);
    expect(responseData.data.cardType).toBe('SUCCESS');
    expect(['Last Recharge', 'Your Last Recharge']).toContain(responseData.data.title);
    expect(responseData.data.amount).toBe(249);
    expect(responseData.data.status).toBe('SUCCESS');
  });

  test('TEST 4 — USER WITH PENDING RECHARGE: Prioritizes active PENDING transaction', async () => {
    await RechargeTransaction.create({
      orderId: 'ORD_SMART_PENDING_1',
      userId: testUser._id,
      operatorCode: 'JO',
      circleCode: '1',
      mobileNumber: testPhone,
      amount: 299,
      payableAmount: 296,
      status: 'PENDING',
    });

    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.data.cardType).toBe('PENDING');
    expect(responseData.data.title).toBe('Recharge in Progress');
    expect(responseData.data.amount).toBe(299);
  });

  test('TEST 5 — USER WITH FAILED RECHARGE: Prioritizes FAILED transaction when pending completes', async () => {
    // Remove pending transaction
    await RechargeTransaction.deleteMany({ userId: testUser._id, status: 'PENDING' });

    await RechargeTransaction.create({
      orderId: 'ORD_SMART_FAILED_1',
      userId: testUser._id,
      operatorCode: 'VI',
      circleCode: '1',
      mobileNumber: testPhone,
      amount: 199,
      payableAmount: 197,
      status: 'FAILED',
      failureReason: 'Operator Gateway Timeout',
    });

    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.data.cardType).toBe('FAILED');
    expect(responseData.data.title).toBe('Recharge Failed');
    expect(responseData.data.failureReason).toBe('Operator Gateway Timeout');
  });

  test('TEST 6 — PLAN EXPIRING > 7 DAYS: Returns GREEN color state', async () => {
    await RechargeTransaction.deleteMany({ userId: testUser._id });
    await UserPlanCache.deleteMany({ userId: testUser._id });

    await UserPlanCache.create({
      userId: testUser._id,
      mobileNumber: testPhone,
      operatorCode: 'AT',
      operatorName: 'Airtel',
      validity: '28 Days',
      expiryDate: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000), // 15 days
      fetchedAt: new Date(),
    });

    const req = { user: testUser };
    let responseData;
    const res = { status: (code) => res, json: (data) => { responseData = data; return res; } };

    await personalController.getLastRecharge(req, res);
    expect(responseData.data.colorState).toBe('GREEN');
    expect(responseData.data.daysRemaining).toBe(15);
  });

  test('TEST 7 — PLAN EXPIRING 3-7 DAYS: Returns AMBER color state', async () => {
    await UserPlanCache.findOneAndUpdate(
      { userId: testUser._id },
      { expiryDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000), fetchedAt: new Date() }
    );

    const req = { user: testUser };
    let responseData;
    const res = { status: (code) => res, json: (data) => { responseData = data; return res; } };

    await personalController.getLastRecharge(req, res);
    expect(responseData.data.colorState).toBe('AMBER');
    expect(responseData.data.daysRemaining).toBe(5);
  });

  test('TEST 8 — PLAN EXPIRING 0-2 DAYS: Returns RED color state', async () => {
    await UserPlanCache.findOneAndUpdate(
      { userId: testUser._id },
      { expiryDate: new Date(Date.now() + 1 * 24 * 60 * 60 * 1000), fetchedAt: new Date() }
    );

    const req = { user: testUser };
    let responseData;
    const res = { status: (code) => res, json: (data) => { responseData = data; return res; } };

    await personalController.getLastRecharge(req, res);
    expect(responseData.data.colorState).toBe('RED');
    expect(responseData.data.daysRemaining).toBe(1);
  });

  test('TEST 9 — EXPIRED PLAN: Returns EXPIRED color state', async () => {
    await UserPlanCache.findOneAndUpdate(
      { userId: testUser._id },
      { expiryDate: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), fetchedAt: new Date() }
    );

    const req = { user: testUser };
    let responseData;
    const res = { status: (code) => res, json: (data) => { responseData = data; return res; } };

    await personalController.getLastRecharge(req, res);
    expect(responseData.data.colorState).toBe('EXPIRED');
    expect(responseData.data.title).toBe('Plan Expired');
  });

  test('TEST 10 — PLANSAPI FAILURE HANDLED GRACEFULLY: Returns NO_PLAN without crashing', async () => {
    await UserPlanCache.deleteMany({ userId: testUser._id });
    const spy = jest.spyOn(planApiService, 'detectMobileOperator').mockRejectedValue(new Error('Network error'));

    const req = { user: testUser };
    let responseData;
    const res = { status: (code) => res, json: (data) => { responseData = data; return res; } };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.data.cardType).toBe('NO_PLAN');
    expect(responseData.data.statusText).toContain('No active plan');

    spy.mockRestore();
  });
});
