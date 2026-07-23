const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Notification = require('../models/Notification');
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
    
    // In a real app, integrate MSG91 Send OTP API here.
    // Since our app uses MSG91 widget heavily, the client might skip this
    // and directly use the widget. This endpoint acts as a fallback / mock.
    
    res.status(200).json({
      success: true,
      message: 'OTP sent to registered mobile number. Temp OTP is 123456.',
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
    const { otp, accessToken } = req.body;
    const user = req.user;

    let isVerified = false;

    if (accessToken) {
      // MSG91 Widget verification
      try {
        const msg91AuthKey = process.env.MSG91_AUTH_KEY;
        console.log('[MSG91] Initialization Status: Checking environment variables');
        console.log('[MSG91] Loaded env keys (no secrets):', Object.keys(process.env).filter(k => k.startsWith('MSG91')));

        const msg91Url = 'https://api.msg91.com/api/v5/widget/verifyAccessToken';
        const msg91Payload = { 'access-token': accessToken };
        const msg91Headers = {
          'Content-Type': 'application/json',
          'authkey': msg91AuthKey
        };

        const msg91Response = await axios.post(msg91Url, msg91Payload, { headers: msg91Headers });

        console.log('[MSG91] Raw response body:', JSON.stringify(msg91Response.data));

        if (msg91Response.data.type === 'success' || msg91Response.data.message === 'Token successfully verified.') {
          isVerified = true;
        } else {
          throw new Error('MSG91 Token verification failed');
        }
      } catch (err) {
        console.error('[MSG91] Verification Error:', err.response?.data || err.message);
        res.status(401);
        throw new Error('Invalid or expired MSG91 access token.');
      }
    } else if (otp) {
      // Fallback mock OTP verification
      if (otp === '123456') {
        isVerified = true;
      } else {
        res.status(401);
        throw new Error('Invalid OTP.');
      }
    } else {
      res.status(400);
      throw new Error('Either OTP or MSG91 accessToken is required.');
    }

    if (isVerified) {
      // Generate a short-lived reset token
      const resetToken = jwt.sign({ id: user._id, purpose: 'mpin_reset' }, process.env.JWT_SECRET, {
        expiresIn: '15m',
      });

      res.status(200).json({
        success: true,
        message: 'OTP verified successfully.',
        data: { resetToken },
      });
    }
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
