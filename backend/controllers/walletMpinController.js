const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const notificationService = require('../services/notification.service');
const Otp = require('../models/Otp');
const fast2smsService = require('../services/fast2sms.service');

// Helper to validate 6-digit Wallet MPIN rules
const validateMpinRules = (mpin) => {
  if (!mpin || mpin.length !== 6 || !/^\d+$/.test(mpin)) {
    return 'Wallet MPIN must be exactly 6 digits.';
  }
  if (/^(\d)\1{5}$/.test(mpin)) {
    return 'Wallet MPIN cannot contain all repeated digits (e.g., 111111).';
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
    return 'Wallet MPIN cannot be sequential (e.g., 123456 or 654321).';
  }
  return null;
};

// @desc    Create a new Wallet MPIN (for users who don't have one)
// @route   POST /api/wallet-mpin/create
// @access  Private
const createMpin = async (req, res, next) => {
  try {
    const { mpin, walletMpin } = req.body;
    const inputMpin = walletMpin || mpin;
    const user = req.user;

    if (user.walletMpinHash || user.mpinHash) {
      res.status(400);
      throw new Error('Wallet MPIN is already configured. Use change Wallet MPIN flow.');
    }

    const validationError = validateMpinRules(inputMpin);
    if (validationError) {
      res.status(400);
      throw new Error(validationError);
    }

    const salt = await bcrypt.genSalt(10);
    const hashedMpin = await bcrypt.hash(inputMpin, salt);

    user.walletMpinHash = hashedMpin;
    user.walletMpinCreatedAt = new Date();
    user.walletMpinUpdatedAt = new Date();
    user.failedWalletMpinAttempts = 0;
    user.walletMpinLockUntil = undefined;
    await user.save();

    notificationService.notifyWalletMpinSetSuccess({ userId: user._id });

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
    const { mpin, walletMpin } = req.body;
    const inputMpin = walletMpin || mpin;
    const user = req.user;

    if (!inputMpin) {
      res.status(400);
      throw new Error('Wallet MPIN is required');
    }

    const isMatch = await user.matchWalletMpin(inputMpin);

    if (!isMatch) {
      res.status(401);
      const attemptsLeft = 5 - (user.failedWalletMpinAttempts || user.failedMpinAttempts || 0);
      throw new Error(
        attemptsLeft > 0
          ? `Incorrect Wallet MPIN. ${attemptsLeft} attempts remaining.`
          : 'Incorrect Wallet MPIN. Wallet payment locked for 15 minutes.'
      );
    }

    res.status(200).json({
      success: true,
      message: 'Wallet MPIN verified successfully',
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
    const { currentMpin, newMpin, currentWalletMpin, newWalletMpin } = req.body;
    const currentInput = currentWalletMpin || currentMpin;
    const newInput = newWalletMpin || newMpin;
    const user = req.user;

    if (!currentInput || !newInput) {
      res.status(400);
      throw new Error('Both current and new Wallet MPINs are required.');
    }

    const validationError = validateMpinRules(newInput);
    if (validationError) {
      res.status(400);
      throw new Error(validationError);
    }

    const isMatch = await user.matchWalletMpin(currentInput);
    if (!isMatch) {
      res.status(401);
      throw new Error('Incorrect current Wallet MPIN.');
    }

    const salt = await bcrypt.genSalt(10);
    const hashedMpin = await bcrypt.hash(newInput, salt);

    user.walletMpinHash = hashedMpin;
    user.walletMpinUpdatedAt = new Date();
    user.failedWalletMpinAttempts = 0;
    user.walletMpinLockUntil = undefined;
    await user.save();

    notificationService.notifyWalletMpinChangedSuccess({ userId: user._id });

    res.status(200).json({
      success: true,
      message: 'Wallet MPIN changed successfully.',
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Send OTP for Forgot Wallet MPIN flow
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

    const otp = crypto.randomInt(100000, 1000000).toString();
    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otp, salt);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

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
      message: 'OTP sent to your registered mobile number for Wallet MPIN reset.',
      data: { phone: user.phone },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Verify OTP for Forgot Wallet MPIN flow
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

    const resetToken = jwt.sign(
      { id: user._id, purpose: 'wallet_mpin_reset' },
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

// @desc    Reset Wallet MPIN after OTP verification
// @route   POST /api/wallet-mpin/reset
// @access  Private
const resetMpin = async (req, res, next) => {
  try {
    const { resetToken, newMpin, newWalletMpin } = req.body;
    const newInput = newWalletMpin || newMpin;
    const user = req.user;

    if (!resetToken || !newInput) {
      res.status(400);
      throw new Error('resetToken and newWalletMpin are required.');
    }

    try {
      const decoded = jwt.verify(resetToken, process.env.JWT_SECRET);
      if (decoded.id !== user._id.toString() || (decoded.purpose !== 'wallet_mpin_reset' && decoded.purpose !== 'mpin_reset')) {
        throw new Error('Invalid reset token.');
      }
    } catch (err) {
      res.status(401);
      throw new Error('Invalid or expired reset token. Please verify OTP again.');
    }

    const validationError = validateMpinRules(newInput);
    if (validationError) {
      res.status(400);
      throw new Error(validationError);
    }

    const salt = await bcrypt.genSalt(10);
    const hashedMpin = await bcrypt.hash(newInput, salt);

    user.walletMpinHash = hashedMpin;
    user.walletMpinUpdatedAt = new Date();
    user.failedWalletMpinAttempts = 0;
    user.walletMpinLockUntil = undefined;
    await user.save();

    notificationService.notifyWalletMpinResetSuccess({ userId: user._id });

    res.status(200).json({
      success: true,
      message: 'Wallet MPIN reset successfully.',
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get Wallet MPIN Status
// @route   GET /api/wallet-mpin/status
// @access  Private
const getStatus = async (req, res, next) => {
  try {
    const user = req.user;
    const isConfigured = !!(user.walletMpinHash || user.mpinHash);
    const activeLock = user.walletMpinLockUntil || user.lockUntil;
    const isLocked = activeLock && activeLock > Date.now();

    res.status(200).json({
      success: true,
      data: {
        walletMpinConfigured: isConfigured,
        isLocked,
        lockUntil: activeLock,
        failedAttempts: user.failedWalletMpinAttempts || user.failedMpinAttempts || 0,
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
