const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const notificationService = require('../services/notification.service');
const Otp = require('../models/Otp');
const fast2smsService = require('../services/fast2sms.service');

// Helper to validate 6-digit Security PIN rules
const validateSecurityPinRules = (pin) => {
  if (!pin || pin.length !== 6 || !/^\d+$/.test(pin)) {
    return 'Security PIN must be exactly 6 digits.';
  }
  if (/^(\d)\1{5}$/.test(pin)) {
    return 'Security PIN cannot contain all repeated digits (e.g., 111111).';
  }
  const isSequential = (str) => {
    let asc = true, desc = true;
    for (let i = 1; i < str.length; i++) {
      if (str.charCodeAt(i) !== str.charCodeAt(i - 1) + 1) asc = false;
      if (str.charCodeAt(i) !== str.charCodeAt(i - 1) - 1) desc = false;
    }
    return asc || desc;
  };
  if (isSequential(pin)) {
    return 'Security PIN cannot be sequential (e.g., 123456 or 654321).';
  }
  return null;
};

// @desc    Create a new Security PIN (for app access)
// @route   POST /api/security-pin/create
// @access  Private
const createSecurityPin = async (req, res, next) => {
  try {
    const { securityPin, pin } = req.body;
    const inputPin = securityPin || pin;
    const user = req.user;

    if (user.securityPinHash) {
      res.status(400);
      throw new Error('Security PIN is already configured. Use change Security PIN flow.');
    }

    const validationError = validateSecurityPinRules(inputPin);
    if (validationError) {
      res.status(400);
      throw new Error(validationError);
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPin = await bcrypt.hash(inputPin, salt);

    user.securityPinHash = hashedPin;
    user.securityPinCreatedAt = new Date();
    user.securityPinUpdatedAt = new Date();
    user.failedSecurityPinAttempts = 0;
    user.securityPinLockUntil = undefined;
    await user.save();

    notificationService.notifySecurityPinSetSuccess({ userId: user._id });

    res.status(200).json({
      success: true,
      message: 'Security PIN created successfully.',
      data: { securityPinConfigured: true },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Verify Security PIN for App Access
// @route   POST /api/security-pin/verify
// @access  Private
const verifySecurityPin = async (req, res, next) => {
  try {
    const { securityPin, pin } = req.body;
    const inputPin = securityPin || pin;
    const user = req.user;

    if (!inputPin) {
      res.status(400);
      throw new Error('Security PIN is required');
    }

    const isMatch = await user.matchSecurityPin(inputPin);

    if (!isMatch) {
      res.status(401);
      const attemptsLeft = 5 - (user.failedSecurityPinAttempts || 0);
      throw new Error(
        attemptsLeft > 0
          ? `Incorrect Security PIN. ${attemptsLeft} attempts remaining.`
          : 'Incorrect Security PIN. App security locked for 15 minutes.'
      );
    }

    res.status(200).json({
      success: true,
      message: 'Security PIN verified successfully',
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Change Security PIN
// @route   POST /api/security-pin/change
// @access  Private
const changeSecurityPin = async (req, res, next) => {
  try {
    const { currentSecurityPin, newSecurityPin, currentPin, newPin } = req.body;
    const currentInput = currentSecurityPin || currentPin;
    const newInput = newSecurityPin || newPin;
    const user = req.user;

    if (!currentInput || !newInput) {
      res.status(400);
      throw new Error('Both current and new Security PINs are required.');
    }

    const validationError = validateSecurityPinRules(newInput);
    if (validationError) {
      res.status(400);
      throw new Error(validationError);
    }

    const isMatch = await user.matchSecurityPin(currentInput);
    if (!isMatch) {
      res.status(401);
      throw new Error('Incorrect current Security PIN.');
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPin = await bcrypt.hash(newInput, salt);

    user.securityPinHash = hashedPin;
    user.securityPinUpdatedAt = new Date();
    user.failedSecurityPinAttempts = 0;
    user.securityPinLockUntil = undefined;
    await user.save();

    notificationService.notifySecurityPinChangedSuccess({ userId: user._id });

    res.status(200).json({
      success: true,
      message: 'Security PIN changed successfully.',
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Send OTP for Forgot Security PIN flow
// @route   POST /api/security-pin/forgot/send-otp
// @access  Private
const sendForgotOtp = async (req, res, next) => {
  try {
    const user = req.user;
    let mobile = user.phone ? String(user.phone).replace(/\D/g, '') : '';
    if (mobile.length > 10 && mobile.startsWith('91')) {
      mobile = mobile.slice(-10);
    }

    if (!mobile || mobile.length !== 10) {
      res.status(400);
      throw new Error('Valid registered mobile number not found on user profile.');
    }

    const otp = crypto.randomInt(100000, 1000000).toString();
    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otp, salt);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await Otp.deleteMany({ mobile, purpose: 'security_pin_reset' });
    await Otp.create({
      mobile,
      purpose: 'security_pin_reset',
      otpHash,
      expiresAt,
      attempts: 0,
      resendCount: 0,
      lastSentAt: new Date(),
    });

    await fast2smsService.sendSecurityPinResetOtp({ mobile, otp });

    res.status(200).json({
      success: true,
      message: 'OTP sent to your registered mobile number for Security PIN reset.',
      data: { phone: user.phone },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Verify OTP for Forgot Security PIN flow
// @route   POST /api/security-pin/forgot/verify-otp
// @access  Private
const verifyForgotOtp = async (req, res, next) => {
  try {
    const { otp } = req.body;
    const user = req.user;

    let mobile = user.phone ? String(user.phone).replace(/\D/g, '') : '';
    if (mobile.length > 10 && mobile.startsWith('91')) {
      mobile = mobile.slice(-10);
    }

    if (!otp || String(otp).trim().length !== 6) {
      res.status(400);
      throw new Error('Please enter a valid 6-digit OTP.');
    }

    const otpRecord = await Otp.findOne({ mobile, purpose: 'security_pin_reset' });

    if (!otpRecord) {
      res.status(400);
      throw new Error('OTP has expired or is invalid. Please request a new OTP.');
    }

    if (otpRecord.expiresAt < new Date()) {
      await Otp.deleteOne({ _id: otpRecord._id });
      res.status(400);
      throw new Error('OTP has expired. Please request a new OTP.');
    }

    if (otpRecord.attempts >= 5) {
      await Otp.deleteOne({ _id: otpRecord._id });
      res.status(400);
      throw new Error('Maximum verification attempts exceeded. Please request a new OTP.');
    }

    const isMatch = await bcrypt.compare(String(otp).trim(), otpRecord.otpHash);

    if (!isMatch) {
      otpRecord.attempts += 1;
      await otpRecord.save();
      const attemptsLeft = 5 - otpRecord.attempts;
      res.status(400);
      throw new Error(`Invalid OTP. ${attemptsLeft} attempt(s) remaining.`);
    }

    await Otp.deleteOne({ _id: otpRecord._id });

    const resetToken = jwt.sign(
      { id: user._id, purpose: 'security_pin_reset' },
      process.env.JWT_SECRET,
      { expiresIn: '15m' }
    );

    res.status(200).json({
      success: true,
      message: 'OTP verified successfully.',
      data: { resetToken },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Reset Security PIN after OTP verification
// @route   POST /api/security-pin/reset
// @access  Private
const resetSecurityPin = async (req, res, next) => {
  try {
    const { resetToken, newSecurityPin, newPin } = req.body;
    const newInput = newSecurityPin || newPin;
    const user = req.user;

    if (!resetToken || !newInput) {
      res.status(400);
      throw new Error('resetToken and newSecurityPin are required.');
    }

    try {
      const decoded = jwt.verify(resetToken, process.env.JWT_SECRET);
      if (decoded.id !== user._id.toString() || decoded.purpose !== 'security_pin_reset') {
        throw new Error('Invalid reset token.');
      }
    } catch (err) {
      res.status(401);
      throw new Error('Invalid or expired reset token. Please verify OTP again.');
    }

    const validationError = validateSecurityPinRules(newInput);
    if (validationError) {
      res.status(400);
      throw new Error(validationError);
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPin = await bcrypt.hash(newInput, salt);

    user.securityPinHash = hashedPin;
    user.securityPinUpdatedAt = new Date();
    user.failedSecurityPinAttempts = 0;
    user.securityPinLockUntil = undefined;
    await user.save();

    notificationService.notifySecurityPinResetSuccess({ userId: user._id });

    res.status(200).json({
      success: true,
      message: 'Security PIN reset successfully.',
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get Security PIN Status
// @route   GET /api/security-pin/status
// @access  Private
const getStatus = async (req, res, next) => {
  try {
    const user = req.user;

    res.status(200).json({
      success: true,
      data: {
        securityPinConfigured: !!user.securityPinHash,
        isLocked: user.securityPinLockUntil && user.securityPinLockUntil > Date.now(),
        lockUntil: user.securityPinLockUntil,
        failedAttempts: user.failedSecurityPinAttempts || 0,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createSecurityPin,
  verifySecurityPin,
  changeSecurityPin,
  sendForgotOtp,
  verifyForgotOtp,
  resetSecurityPin,
  getStatus,
};
