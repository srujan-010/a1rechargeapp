const mongoose = require('mongoose');
const User = require('../models/User');
const RechargeTransaction = require('../models/RechargeTransaction');
const personalController = require('../controllers/personalController');
const planApiService = require('../services/planapi.service');

describe('Personal Home Plan & Last Recharge Audit Fix Test Suite', () => {
  const airtelNumber = '9876543210';
  const bsnlNumber = '9421729714';
  let testUser;

  beforeAll(async () => {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test');
    }

    await User.deleteMany({ phone: { $in: [airtelNumber, `+91${airtelNumber}`] } });
    await RechargeTransaction.deleteMany({ mobileNumber: airtelNumber });

    testUser = await User.create({
      retailerId: 'PLAN_FIX_USER_1',
      phone: airtelNumber,
      name: 'Plan Fix User',
      accountType: 'PERSONAL',
      role: 'retailer',
      isOnboarded: true,
      isVerified: true,
    });
  });

  afterAll(async () => {
    await User.deleteMany({ _id: testUser._id });
    await RechargeTransaction.deleteMany({ userId: testUser._id });
    await mongoose.connection.close();
  });

  test('TEST 1 — BRAND NEW USER WITH NO RECHARGE: Returns "No active plan yet"', async () => {
    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.hasActivePlan).toBe(false);
    expect(responseData.hasLastRecharge).toBe(false);
    expect(responseData.data.statusText).toBe('No active plan yet');
  });

  test('TEST 2 — USER WITH SUCCESSFUL A1 RECHARGE TRANSACTION: Returns last recharge data', async () => {
    await RechargeTransaction.create({
      orderId: 'ORD_PLAN_FIX_SUCCESS_1',
      userId: testUser._id,
      operatorCode: 'AT',
      internalOperatorName: 'Airtel',
      circleCode: '1',
      mobileNumber: airtelNumber,
      amount: 349,
      payableAmount: 346.2,
      commissionAmount: 2.8,
      status: 'SUCCESS',
    });

    const spyLast = jest.spyOn(planApiService, 'checkLastRecharge').mockResolvedValue({ supported: true, success: false });
    const spyExp = jest.spyOn(planApiService, 'checkRechargeExpiry').mockResolvedValue({ supported: true, success: false });

    const req = { user: testUser };
    let responseData;
    const res = { status: (code) => res, json: (data) => { responseData = data; return res; } };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.hasLastRecharge).toBe(true);
    expect(responseData.source).toBe('a1_recharge');
    expect(responseData.lastRecharge.amount).toBe(349);
    expect(responseData.lastRecharge.operator).toBe('Airtel');

    spyLast.mockRestore();
    spyExp.mockRestore();
  });

  test('TEST 3 & 4 — SUPPORTED AIRTEL NUMBER WITH PLANAPI EXPIRY DATA: Returns hasActivePlan: true', async () => {
    const spyLast = jest.spyOn(planApiService, 'checkLastRecharge').mockResolvedValue({
      supported: true,
      success: true,
      data: { amount: '349', rechargeDate: '2026-08-23' },
    });
    const spyExp = jest.spyOn(planApiService, 'checkRechargeExpiry').mockResolvedValue({
      supported: true,
      success: true,
      data: { outgoing: '2026-09-20', incoming: '2026-09-27' },
    });

    const req = { user: testUser };
    let responseData;
    const res = { status: (code) => res, json: (data) => { responseData = data; return res; } };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.hasActivePlan).toBe(true);
    expect(responseData.source).toBe('planapi');
    expect(responseData.outgoing).toBe('2026-09-20');
    expect(responseData.incoming).toBe('2026-09-27');

    spyLast.mockRestore();
    spyExp.mockRestore();
  });

  test('TEST 5 — UNSUPPORTED OPERATOR (BSNL): Falls back to A1 Recharge history without PlanAPI call', async () => {
    const bsnlUser = await User.create({
      retailerId: 'PLAN_FIX_BSNL_1',
      phone: bsnlNumber,
      name: 'BSNL User',
      accountType: 'PERSONAL',
    });

    await RechargeTransaction.create({
      orderId: 'ORD_PLAN_FIX_BSNL_1',
      userId: bsnlUser._id,
      operatorCode: 'BT',
      internalOperatorName: 'BSNL',
      circleCode: '1',
      mobileNumber: bsnlNumber,
      amount: 153,
      payableAmount: 151.1,
      commissionAmount: 1.9,
      status: 'SUCCESS',
    });

    const spyLast = jest.spyOn(planApiService, 'checkLastRecharge');
    const spyExp = jest.spyOn(planApiService, 'checkRechargeExpiry');

    const req = { user: bsnlUser };
    let responseData;
    const res = { status: (code) => res, json: (data) => { responseData = data; return res; } };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.hasActivePlan).toBe(false);
    expect(responseData.hasLastRecharge).toBe(true);
    expect(responseData.source).toBe('a1_recharge');
    expect(responseData.lastRecharge.amount).toBe(153);
    expect(spyLast).not.toHaveBeenCalled();

    spyLast.mockRestore();
    spyExp.mockRestore();
    await User.deleteMany({ _id: bsnlUser._id });
    await RechargeTransaction.deleteMany({ userId: bsnlUser._id });
  });

  test('TEST 6 — SUCCESSFUL NEW RECHARGE: Updates Home card with latest transaction', async () => {
    await RechargeTransaction.create({
      orderId: 'ORD_PLAN_FIX_LATEST_1',
      userId: testUser._id,
      operatorCode: 'AT',
      internalOperatorName: 'Airtel',
      circleCode: '1',
      mobileNumber: airtelNumber,
      amount: 479,
      payableAmount: 475.1,
      commissionAmount: 3.9,
      status: 'SUCCESS',
    });

    const spyLast = jest.spyOn(planApiService, 'checkLastRecharge').mockResolvedValue({ supported: true, success: false });
    const spyExp = jest.spyOn(planApiService, 'checkRechargeExpiry').mockResolvedValue({ supported: true, success: false });

    const req = { user: testUser };
    let responseData;
    const res = { status: (code) => res, json: (data) => { responseData = data; return res; } };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.hasLastRecharge).toBe(true);
    expect(responseData.lastRecharge.amount).toBe(479);

    spyLast.mockRestore();
    spyExp.mockRestore();
  });

  test('TEST 7 — PLANAPI UNAVAILABLE: Gracefully falls back to available A1 Recharge data', async () => {
    const spyLast = jest.spyOn(planApiService, 'checkLastRecharge').mockRejectedValue(new Error('PlanAPI Timeout'));
    const spyExp = jest.spyOn(planApiService, 'checkRechargeExpiry').mockRejectedValue(new Error('PlanAPI Timeout'));

    const req = { user: testUser };
    let responseData;
    const res = { status: (code) => res, json: (data) => { responseData = data; return res; } };

    await personalController.getLastRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.hasLastRecharge).toBe(true);
    expect(responseData.source).toBe('a1_recharge');

    spyLast.mockRestore();
    spyExp.mockRestore();
  });
});
