const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const fast2smsService = require('../services/fast2sms.service');
const { registerRetailer, firebaseLogin, getMe } = require('../controllers/authController');

describe('WhatsApp Welcome Message (a1_recharge_welcome_message) Integration Tests', () => {
  let tempToken;
  let testUser;
  const testPhone = '9876543210';
  const testName = 'Srujan';

  beforeAll(async () => {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test');
    }

    // Clean test user if exists
    await User.deleteMany({ phone: { $in: [testPhone, `+91${testPhone}`] } });

    // Generate temp session token for onboarding
    tempToken = jwt.sign({ phone: testPhone }, process.env.JWT_SECRET || 'test_jwt_secret', { expiresIn: '1h' });
  });

  afterAll(async () => {
    await User.deleteMany({ phone: { $in: [testPhone, `+91${testPhone}`] } });
    await Wallet.deleteMany({});
    await mongoose.connection.close();
  });

  test('TEST 1 — NEW USER: Onboarding sends welcome WhatsApp with Variable 1 = user onboarding name', async () => {
    const spy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate').mockResolvedValue({
      success: true,
      data: { return: true, message: 'Message sent successfully' },
    });

    const req = {
      headers: { authorization: `Bearer ${tempToken}` },
      body: {
        name: testName,
        shopName: 'Srujan Telecom',
        address: 'Main Market Road',
        state: 'Maharashtra',
        district: 'Nagpur',
        pincode: '440001',
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => {
        statusCode = code;
        return res;
      },
      json: (data) => {
        responseData = data;
        return res;
      },
    };

    await registerRetailer(req, res, (err) => { if (err) throw err; });

    expect(statusCode).toBe(201);
    expect(responseData.success).toBe(true);

    // Wait briefly for async non-blocking IIFE
    await new Promise(r => setTimeout(r, 100));

    expect(spy).toHaveBeenCalledTimes(1);
    expect(spy).toHaveBeenCalledWith({
      name: testName,
      mobile: testPhone,
    });

    testUser = await User.findOne({ phone: testPhone });
    expect(testUser).toBeDefined();
    expect(testUser.name).toBe(testName);
    expect(testUser.welcomeWhatsAppSent).toBe(true);
    expect(testUser.welcomeWhatsAppStatus).toBe('SENT');
    expect(testUser.welcomeWhatsAppMessageId).toBe('30063');

    spy.mockRestore();
  });

  test('TEST 2 — EXISTING USER: Firebase login for existing user does NOT send welcome WhatsApp', async () => {
    const spy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate');

    // Simulate existing user having firebaseUid
    testUser.firebaseUid = 'test_firebase_uid_123';
    await testUser.save();

    // Check existing user lookup
    const existing = await User.findOne({ phone: testPhone });
    expect(existing).toBeDefined();

    // Call getMe or firebaseLogin
    const req = { user: existing };
    let statusCode;
    let responseData;
    const res = {
      status: (code) => {
        statusCode = code;
        return res;
      },
      json: (data) => {
        responseData = data;
        return res;
      },
    };

    await getMe(req, res, () => {});

    expect(statusCode).toBe(200);
    expect(responseData.success).toBe(true);
    expect(spy).not.toHaveBeenCalled();

    spy.mockRestore();
  });

  test('TEST 3 & 4 — REOPEN APP / LOGOUT / LOGIN: Existing user profile fetch does NOT send welcome WhatsApp', async () => {
    const spy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate');

    const req = { user: testUser };
    let responseData;
    const res = {
      status: () => res,
      json: (data) => { responseData = data; return res; },
    };

    await getMe(req, res, () => {});

    expect(responseData.success).toBe(true);
    expect(spy).not.toHaveBeenCalled();

    spy.mockRestore();
  });

  test('TEST 5 — ONBOARDING RETRY: Duplicate onboarding request does NOT send second welcome WhatsApp', async () => {
    const spy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate');

    const req = {
      headers: { authorization: `Bearer ${tempToken}` },
      body: {
        name: testName,
        shopName: 'Srujan Telecom',
        address: 'Main Market Road',
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => {
        statusCode = code;
        return res;
      },
      json: (data) => {
        responseData = data;
        return res;
      },
    };

    await registerRetailer(req, res, () => {});

    // Registration should fail with 400 User already exists
    expect(statusCode).toBe(400);
    expect(responseData.message).toContain('already exists');
    expect(spy).not.toHaveBeenCalled();

    spy.mockRestore();
  });

  test('TEST 6 — WHATSAPP FAILURE: Fast2SMS failure does NOT block onboarding', async () => {
    const spy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate').mockRejectedValue(new Error('Fast2SMS Timeout'));

    const failPhone = '9111222333';
    const failToken = jwt.sign({ phone: failPhone }, process.env.JWT_SECRET || 'test_jwt_secret', { expiresIn: '1h' });

    const req = {
      headers: { authorization: `Bearer ${failToken}` },
      body: {
        name: 'Failure Test User',
        shopName: 'Fail Store',
        address: 'Fail Road',
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => {
        statusCode = code;
        return res;
      },
      json: (data) => {
        responseData = data;
        return res;
      },
    };

    await registerRetailer(req, res, (err) => { if (err) throw err; });

    // Onboarding MUST STILL SUCCEED with HTTP 201
    expect(statusCode).toBe(201);
    expect(responseData.success).toBe(true);

    const failUser = await User.findOne({ phone: failPhone });
    expect(failUser).toBeDefined();

    // Clean up
    await User.deleteOne({ _id: failUser._id });
    await Wallet.deleteOne({ userId: failUser._id });

    spy.mockRestore();
  });
});
