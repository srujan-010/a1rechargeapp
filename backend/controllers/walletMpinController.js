const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Notification = require('../models/Notification');
const Otp = require('../models/Otp');
const fast2smsService = require('../services/fast2sms.service');
const axios = require('axios');

// Helper to validate 6-digit MPIN rules
const validateMpinRules = (mpin) => {
  if (!mpin || mpin.length !== 6 || !/^\d+$/.test(mpin)) {
    return 'MPIN must be exactly 6 digits.';
  }
  if (/^(\d)\1{5}$/.test(mpin)) {
    return 'MPIN cannot contain all repeated digits (e.g., 111111).';
  }
  // Check sequential (e.g., 123456, 654321)
  const isSequential = (str) => {
    let asc = true, desc = true;
    for (let i = 1; i < str.length; i++) {
      if (str.charCodeAt(i) !== str.charCodeAt(i - 1) + 1) asc = false;
      if (str.charCodeAt(i) !== str.charCodeAt(i - 1) - 1) desc = false;
    }
    return asc || desc;
  };
  if (isSequential(mpin)) {
    return 'MPIN cannot be sequential (e.g., 123456 or 654321).';
  }
  return null;
};

// @desc    Create a new Wallet MPIN (for users who don't have one)
// @route   POST /api/wallet-mpin/create
// @access  Private
const createMpin = async (req, res, next) => {
  try {
    const { mpin } = req.body;
    const user = req.user;

    if (user.mpinHash) {
      res.status(400);
      throw new Error('MPIN is already configured. Use change MPIN flow.');
    }

    const validationError = validateMpinRules(mpin);
    if (validationError) {
      res.status(400);
      throw new Error(validationError);
    }

    const salt = await bcrypt.genSalt(10);
    const hashedMpin = await bcrypt.hash(mpin, salt);

    user.mpinHash = hashedMpin;
    user.mpinCreatedAt = new Date();
    user.mpinUpdatedAt = new Date();
    user.failedMpinAttempts = 0;
    user.lockUntil = undefined;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Wallet MPIN created successfully.',
      data: { walletMpinConfigured: true },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Verify Wallet MPIN before a transaction
// @route   POST /api/wallet-mpin/verify
// @access  Private
const verifyMpin = async (req, res, next) => {
  try {
    const { mpin } = req.body;
    const user = req.user;

    if (!mpin) {
      res.status(400);
      throw new Error('MPIN is required');
    }

    // The user schema matchMpin method handles the 5-attempt lockout logic
    const isMatch = await user.matchMpin(mpin);

    if (!isMatch) {
      res.status(401);
      const attemptsLeft = 5 - user.failedMpinAttempts;
      throw new Error(attemptsLeft > 0 
        ? `Incorrect MPIN. ${attemptsLeft} attempts remaining.` 
        : 'Incorrect MPIN. Account locked for 15 minutes.');
    }

    res.status(200).json({
      success: true,
      message: 'MPIN verified successfully',
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Change Wallet MPIN securely
// @route   POST /api/wallet-mpin/change
// @access  Private
const changeMpin = async (req, res, next) => {
  try {
    const { currentMpin, newMpin } = req.body;
    const user = req.user;

    if (!currentMpin || !newMpin) {
      res.status(400);
      throw new Error('Both current and new MPINs are required.');
    }

    const validationError = validateMpinRules(newMpin);
    if (validationError) {
      res.status(400);
      throw new Error(validationError);
    }

    const isMatch = await user.matchMpin(currentMpin);
    if (!isMatch) {
      res.status(401);
      throw new Error('Incorrect current MPIN.');
    }

    const salt = await bcrypt.genSalt(10);
    const hashedMpin = await bcrypt.hash(newMpin, salt);

    user.mpinHash = hashedMpin;
    user.mpinUpdatedAt = new Date();
    user.failedMpinAttempts = 0;
    user.lockUntil = undefined;
    await user.save();

    await Notification.create({
      userId: user._id,
      title: 'Wallet MPIN Changed',
      message: 'Your Wallet MPIN was changed successfully.',
      category: 'SECURITY',
      priority: 'HIGH'
    });

    res.status(200).json({
      success: true,
      message: 'Wallet MPIN changed successfully.',
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Send OTP for Forgot MPIN flow
// @route   POST /api/wallet-mpin/forgot/send-otp
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

    // Generate 6-digit OTP
    const otp = crypto.randomInt(100000, 1000000).toString();
    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otp, salt);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 mins

    await Otp.deleteMany({ mobile });
    await Otp.create({
      mobile,
      otpHash,
      expiresAt,
      attempts: 0,
      resendCount: 0,
      lastSentAt: new Date(),
    });

    await fast2smsService.sendAuthenticationTemplate({ mobile, otp });

    res.status(200).json({
      success: true,
      message: 'OTP sent to your registered mobile number on WhatsApp.',
      data: { phone: user.phone },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Verify OTP for Forgot MPIN flow
// @route   POST /api/wallet-mpin/forgot/verify-otp
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

    const otpRecord = await Otp.findOne({ mobile });

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

    // Generate short-lived reset token for MPIN reset
    const resetToken = jwt.sign({ id: user._id, purpose: 'mpin_reset' }, process.env.JWT_SECRET, {
      expiresIn: '15m',
    });

    res.status(200).json({
      success: true,
      message: 'OTP verified successfully.',
      data: { resetToken },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Reset MPIN after OTP verification
// @route   POST /api/wallet-mpin/reset
// @access  Private
const resetMpin = async (req, res, next) => {
  try {
    const { resetToken, newMpin } = req.body;
    const user = req.user;

    if (!resetToken || !newMpin) {
      res.status(400);
      throw new Error('resetToken and newMpin are required.');
    }

    // Verify reset token
    try {
      const decoded = jwt.verify(resetToken, process.env.JWT_SECRET);
      if (decoded.id !== user._id.toString() || decoded.purpose !== 'mpin_reset') {
        throw new Error('Invalid reset token.');
      }
    } catch (err) {
      res.status(401);
      throw new Error('Invalid or expired reset token. Please verify OTP again.');
    }

    const validationError = validateMpinRules(newMpin);
    if (validationError) {
      res.status(400);
      throw new Error(validationError);
    }

    const salt = await bcrypt.genSalt(10);
    const hashedMpin = await bcrypt.hash(newMpin, salt);

    user.mpinHash = hashedMpin;
    user.mpinUpdatedAt = new Date();
    user.failedMpinAttempts = 0;
    user.lockUntil = undefined;
    await user.save();

    await Notification.create({
      userId: user._id,
      title: 'Wallet MPIN Reset',
      message: 'Your Wallet MPIN was reset successfully.',
      category: 'SECURITY',
      priority: 'HIGH'
    });

    res.status(200).json({
      success: true,
      message: 'Wallet MPIN reset successfully.',
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get MPIN Status
// @route   GET /api/wallet-mpin/status
// @access  Private
const getStatus = async (req, res, next) => {
  try {
    const user = req.user;
    
    res.status(200).json({
      success: true,
      data: {
        walletMpinConfigured: !!user.mpinHash,
        isLocked: user.lockUntil && user.lockUntil > Date.now(),
        lockUntil: user.lockUntil,
        failedAttempts: user.failedMpinAttempts,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createMpin,
  verifyMpin,
  changeMpin,
  sendForgotOtp,
  verifyForgotOtp,
  resetMpin,
  getStatus,
};
