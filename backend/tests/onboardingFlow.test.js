const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const fast2smsService = require('../services/fast2sms.service');
const { registerRetailer, verifyOtp, getMe } = require('../controllers/authController');

describe('Redesigned Onboarding Flow Verification Suite', () => {
  const personalPhone = '9888111222';
  const retailerPhoneWithShop = '9888333444';
  const retailerPhoneNoShop = '9888555666';

  let personalToken;
  let retailerShopToken;
  let retailerNoShopToken;

  beforeAll(async () => {
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test');
    }

    const testPhones = [personalPhone, retailerPhoneWithShop, retailerPhoneNoShop];
    await User.deleteMany({ phone: { $in: testPhones.concat(testPhones.map(p => `+91${p}`)) } });

    personalToken = jwt.sign({ phone: personalPhone }, process.env.JWT_SECRET || 'test_jwt_secret', { expiresIn: '1h' });
    retailerShopToken = jwt.sign({ phone: retailerPhoneWithShop }, process.env.JWT_SECRET || 'test_jwt_secret', { expiresIn: '1h' });
    retailerNoShopToken = jwt.sign({ phone: retailerPhoneNoShop }, process.env.JWT_SECRET || 'test_jwt_secret', { expiresIn: '1h' });
  });

  afterAll(async () => {
    const testPhones = [personalPhone, retailerPhoneWithShop, retailerPhoneNoShop];
    await User.deleteMany({ phone: { $in: testPhones.concat(testPhones.map(p => `+91${p}`)) } });
    await Wallet.deleteMany({});
    await mongoose.connection.close();
  });

  test('TEST 1 — NEW PERSONAL USER: Short onboarding creates PERSONAL account & sends Welcome WhatsApp', async () => {
    const welcomeSpy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate').mockResolvedValue({
      success: true,
      data: { return: true },
    });

    const req = {
      headers: { authorization: `Bearer ${personalToken}` },
      body: {
        accountType: 'PERSONAL',
        name: 'Srujan Personal',
        email: 'personal@srujan.com',
        termsAccepted: true,
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { responseData = data; return res; },
    };

    await registerRetailer(req, res, (err) => { if (err) throw err; });

    expect(statusCode).toBe(201);
    expect(responseData.success).toBe(true);

    await new Promise(r => setTimeout(r, 100));

    expect(welcomeSpy).toHaveBeenCalledWith({
      name: 'Srujan Personal',
      mobile: personalPhone,
    });

    const dbUser = await User.findOne({ phone: personalPhone });
    expect(dbUser).toBeDefined();
    expect(dbUser.accountType).toBe('PERSONAL');
    expect(dbUser.isOnboarded).toBe(true);
    expect(dbUser.hasPhysicalShop).toBe(false);

    welcomeSpy.mockRestore();
  });

  test('TEST 2 — NEW RETAILER WITH SHOP: Complete retailer onboarding with shop address', async () => {
    const welcomeSpy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate').mockResolvedValue({
      success: true,
      data: { return: true },
    });

    const req = {
      headers: { authorization: `Bearer ${retailerShopToken}` },
      body: {
        accountType: 'RETAILER',
        name: 'Srujan Retailer',
        shopName: 'Srujan Telecom Center',
        hasPhysicalShop: true,
        businessType: 'Mobile Recharge Shop',
        address: '12 MG Road Market, Nagpur',
        termsAccepted: true,
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { responseData = data; return res; },
    };

    await registerRetailer(req, res, (err) => { if (err) throw err; });

    expect(statusCode).toBe(201);
    expect(responseData.success).toBe(true);

    await new Promise(r => setTimeout(r, 100));

    const dbUser = await User.findOne({ phone: retailerPhoneWithShop });
    expect(dbUser).toBeDefined();
    expect(dbUser.accountType).toBe('RETAILER');
    expect(dbUser.hasPhysicalShop).toBe(true);
    expect(dbUser.shopName).toBe('Srujan Telecom Center');
    expect(dbUser.businessType).toBe('Mobile Recharge Shop');
    expect(dbUser.isOnboarded).toBe(true);

    welcomeSpy.mockRestore();
  });

  test('TEST 3 — NEW RETAILER WITHOUT SHOP: Online retailer onboarding succeeds without forcing shop address', async () => {
    const welcomeSpy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate').mockResolvedValue({
      success: true,
      data: { return: true },
    });

    const req = {
      headers: { authorization: `Bearer ${retailerNoShopToken}` },
      body: {
        accountType: 'RETAILER',
        name: 'Online Retailer',
        shopName: 'Digital Recharge Services',
        hasPhysicalShop: false,
        businessType: 'CSC / Digital Service Center',
        termsAccepted: true,
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { responseData = data; return res; },
    };

    await registerRetailer(req, res, (err) => { if (err) throw err; });

    expect(statusCode).toBe(201);
    expect(responseData.success).toBe(true);

    const dbUser = await User.findOne({ phone: retailerPhoneNoShop });
    expect(dbUser).toBeDefined();
    expect(dbUser.accountType).toBe('RETAILER');
    expect(dbUser.hasPhysicalShop).toBe(false);
    expect(dbUser.isOnboarded).toBe(true);

    welcomeSpy.mockRestore();
  });

  test('TEST 4 & 5 — EXISTING USERS: Login bypasses onboarding flow and sends NO welcome WhatsApp', async () => {
    const welcomeSpy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate');

    const dbUser = await User.findOne({ phone: personalPhone });
    expect(dbUser.isOnboarded).toBe(true);

    const req = { user: dbUser };
    let responseData;
    const res = {
      status: () => res,
      json: (data) => { responseData = data; return res; },
    };

    await getMe(req, res, () => {});

    expect(responseData.success).toBe(true);
    expect(responseData.data.isOnboarded).toBe(true);
    expect(welcomeSpy).not.toHaveBeenCalled();

    welcomeSpy.mockRestore();
  });

  test('TEST 6 — DUPLICATE SUBMISSION GUARD: Multiple submission returns 400 error and skips second WhatsApp', async () => {
    const welcomeSpy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate');

    const req = {
      headers: { authorization: `Bearer ${personalToken}` },
      body: {
        accountType: 'PERSONAL',
        name: 'Srujan Personal',
        termsAccepted: true,
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { responseData = data; return res; },
    };

    await registerRetailer(req, res, () => {});

    expect(statusCode).toBe(400);
    expect(responseData.message).toContain('already exists');
    expect(welcomeSpy).not.toHaveBeenCalled();

    welcomeSpy.mockRestore();
  });

  test('TEST 7 — APP CLOSED / RESUME ONBOARDING: Incomplete onboarding is resumed & finalized safely', async () => {
    const resumePhone = '9990001112';
    await User.deleteMany({ phone: { $in: [resumePhone, `+91${resumePhone}`] } });
    const resumeToken = jwt.sign({ phone: resumePhone }, process.env.JWT_SECRET || 'test_jwt_secret', { expiresIn: '1h' });

    // Create partial user doc (isOnboarded = false)
    const partialUser = await User.create({
      retailerId: `RET_PARTIAL_${Date.now()}`,
      phone: resumePhone,
      name: 'Partial User',
      isOnboarded: false,
    });

    const welcomeSpy = jest.spyOn(fast2smsService, 'sendWelcomeTemplate').mockResolvedValue({
      success: true,
      data: { return: true },
    });

    const req = {
      headers: { authorization: `Bearer ${resumeToken}` },
      body: {
        accountType: 'PERSONAL',
        name: 'Resumed User Name',
        termsAccepted: true,
      },
    };

    let statusCode;
    let responseData;
    const res = {
      status: (code) => { statusCode = code; return res; },
      json: (data) => { responseData = data; return res; },
    };

    await registerRetailer(req, res, (err) => { if (err) throw err; });

    expect(statusCode).toBe(201);
    expect(responseData.success).toBe(true);

    const updatedUser = await User.findOne({ phone: resumePhone });
    expect(updatedUser.isOnboarded).toBe(true);
    expect(updatedUser.name).toBe('Resumed User Name');

    await User.deleteOne({ _id: partialUser._id });
    await Wallet.deleteOne({ userId: partialUser._id });

    welcomeSpy.mockRestore();
  });
});
