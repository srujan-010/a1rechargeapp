const mongoose = require('mongoose');
const User = require('../models/User');
const RechargeTransaction = require('../models/RechargeTransaction');
const personalController = require('../controllers/personalController');

describe('Personal Home Screen — Last Recharge Acceptance Test Suite', () => {
  const testPhone = '9440751149';
  let testUser;

  beforeAll(async () => {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test');
    }

    await User.deleteMany({ phone: { $in: [testPhone, `+91${testPhone}`] } });
    await RechargeTransaction.deleteMany({ mobileNumber: testPhone });

    testUser = await User.create({
      retailerId: 'LAST_RECHARGE_USER_1',
      phone: testPhone,
      name: 'Last Recharge Tester',
      accountType: 'PERSONAL',
      role: 'retailer',
    });
  });

  afterAll(async () => {
    if (testUser) {
      await User.deleteMany({ _id: testUser._id });
    }
    await RechargeTransaction.deleteMany({ mobileNumber: testPhone });
  });

  beforeEach(async () => {
    await RechargeTransaction.deleteMany({ userId: testUser._id });
  });

  test('TEST 1 — SUCCESSFUL RECHARGE DISPLAY: Customer has successful ₹299 Airtel recharge', async () => {
    await RechargeTransaction.create({
      orderId: 'ORD_SUCCESS_299',
      userId: testUser._id,
      operatorCode: 'AT',
      internalOperatorName: 'Airtel',
      circleCode: '1',
      mobileNumber: testPhone,
      amount: 299,
      payableAmount: 299,
      status: 'SUCCESS',
      createdAt: new Date('2026-08-23T10:00:00Z'),
    });

    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastSuccessfulRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.hasLastSuccessful).toBe(true);
    expect(responseData.data.amount).toBe(299);
    expect(responseData.data.mobileNumber).toBe(testPhone);
    expect(responseData.data.status).toBe('SUCCESS');
  });

  test('TEST 2 — LATEST SUCCESSFUL RECHARGE PRIORITY: ₹299 Airtel followed by successful ₹199 Jio', async () => {
    await RechargeTransaction.create({
      orderId: 'ORD_AIRTEL_299',
      userId: testUser._id,
      operatorCode: 'AT',
      internalOperatorName: 'Airtel',
      circleCode: '1',
      mobileNumber: testPhone,
      amount: 299,
      status: 'SUCCESS',
      createdAt: new Date('2026-08-23T10:00:00Z'),
    });

    await RechargeTransaction.create({
      orderId: 'ORD_JIO_199',
      userId: testUser._id,
      operatorCode: 'JO',
      internalOperatorName: 'Jio',
      circleCode: '1',
      mobileNumber: testPhone,
      amount: 199,
      status: 'SUCCESS',
      createdAt: new Date('2026-08-23T12:00:00Z'),
    });

    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastSuccessfulRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.data.amount).toBe(199); // Latest ₹199 Jio, NOT ₹299
    expect(responseData.data.operator).toBe('Jio');
    expect(responseData.data.status).toBe('SUCCESS');
  });

  test('TEST 3 — FAILED RECHARGE IS IGNORED: ₹299 Airtel SUCCESS followed by ₹199 Jio FAILED', async () => {
    await RechargeTransaction.create({
      orderId: 'ORD_AIRTEL_299',
      userId: testUser._id,
      operatorCode: 'AT',
      internalOperatorName: 'Airtel',
      circleCode: '1',
      mobileNumber: testPhone,
      amount: 299,
      status: 'SUCCESS',
      createdAt: new Date('2026-08-23T10:00:00Z'),
    });

    await RechargeTransaction.create({
      orderId: 'ORD_JIO_FAILED_199',
      userId: testUser._id,
      operatorCode: 'JO',
      internalOperatorName: 'Jio',
      circleCode: '1',
      mobileNumber: testPhone,
      amount: 199,
      status: 'FAILED',
      failureReason: 'Operator Gateway Error',
      createdAt: new Date('2026-08-23T12:00:00Z'),
    });

    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastSuccessfulRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.hasLastSuccessful).toBe(true);
    expect(responseData.data.amount).toBe(299); // Still ₹299 Airtel, NOT ₹199 Failed
    expect(responseData.data.status).toBe('SUCCESS');
  });

  test('TEST 4 — PENDING RECHARGE IS IGNORED FOR LAST SUCCESSFUL: ₹299 Airtel SUCCESS followed by ₹199 Jio PENDING', async () => {
    await RechargeTransaction.create({
      orderId: 'ORD_AIRTEL_299',
      userId: testUser._id,
      operatorCode: 'AT',
      internalOperatorName: 'Airtel',
      circleCode: '1',
      mobileNumber: testPhone,
      amount: 299,
      status: 'SUCCESS',
      createdAt: new Date('2026-08-23T10:00:00Z'),
    });

    await RechargeTransaction.create({
      orderId: 'ORD_JIO_PENDING_199',
      userId: testUser._id,
      operatorCode: 'JO',
      internalOperatorName: 'Jio',
      circleCode: '1',
      mobileNumber: testPhone,
      amount: 199,
      status: 'PENDING',
      createdAt: new Date('2026-08-23T12:00:00Z'),
    });

    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastSuccessfulRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.hasLastSuccessful).toBe(true);
    expect(responseData.data.amount).toBe(299); // Still ₹299 Airtel, NOT ₹199 Pending
    expect(responseData.data.status).toBe('SUCCESS');
  });

  test('TEST 5 — NEW CUSTOMER WITH NO SUCCESSFUL RECHARGE: Returns clean empty response', async () => {
    const req = { user: testUser };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await personalController.getLastSuccessfulRecharge(req, res);

    expect(responseData.success).toBe(true);
    expect(responseData.hasLastSuccessful).toBe(false);
    expect(responseData.data).toBeNull();
  });
});
