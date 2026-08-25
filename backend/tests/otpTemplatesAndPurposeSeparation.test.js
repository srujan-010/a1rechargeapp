const fast2smsService = require('../services/fast2sms.service');
const Otp = require('../models/Otp');
const bcrypt = require('bcryptjs');

describe('Fast2SMS OTP Templates & Purpose Separation Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  // TEST 1: Template methods exist and call unified sender with correct purpose names
  test('TEST 1: Fast2SMS service exposes distinct methods for LOGIN_OTP, SECURITY_PIN_RESET_OTP, and WALLET_PIN_RESET_OTP', async () => {
    expect(typeof fast2smsService.sendLoginOtp).toBe('function');
    expect(typeof fast2smsService.sendSecurityPinResetOtp).toBe('function');
    expect(typeof fast2smsService.sendWalletPinResetOtp).toBe('function');

    const spy = jest.spyOn(fast2smsService, '_sendOtpTemplate').mockResolvedValue({ success: true });

    await fast2smsService.sendLoginOtp({ mobile: '9975600499', otp: '123456' });
    expect(spy).toHaveBeenCalledWith(
      expect.objectContaining({
        mobile: '9975600499',
        otp: '123456',
        purposeName: 'LOGIN_OTP',
      })
    );

    await fast2smsService.sendSecurityPinResetOtp({ mobile: '9975600499', otp: '234567' });
    expect(spy).toHaveBeenCalledWith(
      expect.objectContaining({
        mobile: '9975600499',
        otp: '234567',
        purposeName: 'SECURITY_PIN_RESET_OTP',
      })
    );

    await fast2smsService.sendWalletPinResetOtp({ mobile: '9975600499', otp: '345678' });
    expect(spy).toHaveBeenCalledWith(
      expect.objectContaining({
        mobile: '9975600499',
        otp: '345678',
        purposeName: 'WALLET_PIN_RESET_OTP',
      })
    );

    spy.mockRestore();
  });

  // TEST 2: Environment configuration support phone is 9975600499
  test('TEST 2: Fast2SMS configuration contains support phone 9975600499', () => {
    const config = fast2smsService._getConfig();
    expect(config.supportPhone).toBe('9975600499');
  });

  // TEST 3: Otp schema validates purpose enum values
  test('TEST 3: Otp schema strictly accepts login, security_pin_reset, and wallet_pin_reset purposes', () => {
    const loginOtp = new Otp({
      mobile: '9975600499',
      purpose: 'login',
      otpHash: 'dummyhash',
      expiresAt: new Date(Date.now() + 600000),
    });
    expect(loginOtp.validateSync()).toBeUndefined();

    const secOtp = new Otp({
      mobile: '9975600499',
      purpose: 'security_pin_reset',
      otpHash: 'dummyhash',
      expiresAt: new Date(Date.now() + 600000),
    });
    expect(secOtp.validateSync()).toBeUndefined();

    const walletOtp = new Otp({
      mobile: '9975600499',
      purpose: 'wallet_pin_reset',
      otpHash: 'dummyhash',
      expiresAt: new Date(Date.now() + 600000),
    });
    expect(walletOtp.validateSync()).toBeUndefined();

    const invalidOtp = new Otp({
      mobile: '9975600499',
      purpose: 'invalid_purpose',
      otpHash: 'dummyhash',
      expiresAt: new Date(Date.now() + 600000),
    });
    const err = invalidOtp.validateSync();
    expect(err).toBeDefined();
    expect(err.errors.purpose).toBeDefined();
  });
});
