const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const fast2smsService = require('../services/fast2sms.service');
const notificationService = require('../services/notification.service');
const { registerRetailer, getMe } = require('../controllers/authController');

describe('Disable Automatic Recharge Success WhatsApp Verification Suite', () => {
  const testPhone = '9777666555';
  const testName = 'Recharge User';
  let tempToken;
  let testUser;

  beforeAll(async () => {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test');
    }

    await User.deleteMany({ phone: { $in: [testPhone, `+91${testPhone}`] } });
    tempToken = jwt.sign({ phone: testPhone }, process.env.JWT_SECRET || 'test_jwt_secret', { expiresIn: '1h' });
  });

  afterAll(async () => {
    await User.deleteMany({ phone: { $in: [testPhone, `+91${testPhone}`] } });
    await Wallet.deleteMany({});
    await mongoose.connection.close();
  });

  test('Fast2SMS sendRechargeSuccessTemplate logs disabled message and does NOT make HTTP request', async () => {
    const consoleSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
    const result = await fast2smsService.sendRechargeSuccessTemplate({
      customerName: 'Test Retailer',
      mobileNumber: '9421729714',
      amount: 10,
      operator: 'Airtel',
      transactionId: 'A1R123456789',
    });

    expect(result.success).toBe(true);
    expect(result.skipped).toBe(true);

    const loggedMessages = consoleSpy.mock.calls.map(c => c.join(' '));
    expect(loggedMessages.some(m => m.includes('[WHATSAPP] Recharge success message disabled'))).toBe(true);
    expect(loggedMessages.some(m => m.includes('Template recharge_success / 26992 was NOT sent'))).toBe(true);

    consoleSpy.mockRestore();
  });

  test('New user onboarding STILL sends Welcome WhatsApp (Message ID: 30063)', async () => {
    const welcomeSpy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate').mockResolvedValue({
      success: true,
      data: { return: true },
    });

    const req = {
      headers: { authorization: `Bearer ${tempToken}` },
      body: {
        name: testName,
        shopName: 'Test Telecom',
        address: 'Test City',
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { responseData = data; return res; },
    };

    await registerRetailer(req, res, () => {});

    expect(statusCode).toBe(201);
    expect(responseData.success).toBe(true);

    await new Promise(r => setTimeout(r, 100));

    expect(welcomeSpy).toHaveBeenCalledTimes(1);
    expect(welcomeSpy).toHaveBeenCalledWith({
      name: testName,
      mobile: testPhone,
    });

    testUser = await User.findOne({ phone: testPhone });
    expect(testUser.welcomeWhatsAppSent).toBe(true);

    welcomeSpy.mockRestore();
  });

  test('Existing user profile fetch does NOT send welcome WhatsApp or recharge success WhatsApp', async () => {
    const welcomeSpy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate');
    const rechargeSpy = jest.spyOn(fast2smsService, 'sendRechargeSuccessTemplate');

    const req = { user: testUser };
    let responseData;
    const res = {
      status: () => res,
      json: (data) => { responseData = data; return res; },
    };

    await getMe(req, res, () => {});

    expect(responseData.success).toBe(true);
    expect(welcomeSpy).not.toHaveBeenCalled();
    expect(rechargeSpy).not.toHaveBeenCalled();

    welcomeSpy.mockRestore();
    rechargeSpy.mockRestore();
  });

  test('Firebase Notification (notifyRechargeSuccess) remains 100% active', () => {
    const dispatchSpy = jest.spyOn(notificationService, '_dispatch').mockImplementation(() => {});

    notificationService.notifyRechargeSuccess({
      userId: testUser._id,
      orderId: 'A1R999888',
      amount: 10,
      operator: 'Airtel',
      mobileNumber: '9421729714',
    });

    expect(dispatchSpy).toHaveBeenCalledTimes(1);
    expect(dispatchSpy.mock.calls[0][0].title).toBe('Recharge Successful');
    expect(dispatchSpy.mock.calls[0][0].notificationType).toBe('RECHARGE_SUCCESS');

    dispatchSpy.mockRestore();
  });
});
