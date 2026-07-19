const User = require('../models/User');
const Wallet = require('../models/Wallet');
const Bank = require('../models/Bank');
const Kyc = require('../models/Kyc');
const generateRetailerId = require('../utils/generateRetailerId');
const Notification = require('../models/Notification');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { getApp } = require('../config/firebase');
const { getAuth } = require('firebase-admin/auth');

// Generate backend JWT (session token) for a user id.
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: '30d',
  });
};

const TOKEN_TTL_DAYS = 30;

// Assemble the full client-facing profile from the user document and its
// related Bank / Wallet / Kyc documents. Sensitive fields are masked inside
// the individual toSafeJSON() methods.
const buildProfile = (user, bank, wallet, kyc) => {
  const profile = user.toSafeJSON();
  profile.bank = bank ? bank.toSafeJSON() : null;
  profile.wallet = wallet
    ? {
        balancePaise: wallet.balancePaise,
        currency: wallet.currency,
      }
    : null;
  profile.kyc = kyc ? kyc.toSafeJSON() : null;
  return profile;
};

// Compose the standard success envelope returned on a successful login/register.
const buildAuthResponse = async (user) => {
  const [bank, wallet, kyc] = await Promise.all([
    Bank.findOne({ userId: user._id }),
    Wallet.findOne({ userId: user._id }),
    Kyc.findOne({ userId: user._id }),
  ]);

  return {
    success: true,
    data: {
      isNewUser: false,
      accessToken: generateToken(user._id),
      expiresAt: new Date(
        Date.now() + TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000,
      ).toISOString(),
      user: buildProfile(user, bank, wallet, kyc),
    },
  };
};

// @desc    Initiate Login via Phone (Mock OTP send)
// @route   POST /api/auth/login
// @access  Public
const loginUser = async (req, res, next) => {
  try {
    const { phone } = req.body;
    if (!phone) {
      res.status(400);
      throw new Error('Please include a phone number');
    }

    // In a real app, send OTP via SMS here.
    // For now, temporarily return the hardcoded OTP in the response
    res.status(200).json({
      success: true,
      message: 'OTP sent successfully. Temp OTP is 123456',
      data: { phone, otp: '123456' },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Verify OTP and return token
// @route   POST /api/auth/verify-otp
// @access  Public
const verifyOtp = async (req, res, next) => {
  try {
    const { phone, otp } = req.body;

    // Hardcoded mock OTP
    if (otp !== '123456') {
      res.status(401);
      throw new Error('Invalid OTP');
    }

    let user = await User.findOne({ phone });

    // If user doesn't exist, create them (mock registration)
    if (!user) {
      const retailerId = await generateRetailerId();
      user = await User.create({
        phone,
        name: `User ${phone.substring(6)}`,
        retailerId,
        kycStatus: 'verified',
        isVerified: true,
      });

      // Create empty wallet for new user
      await Wallet.create({
        userId: user._id,
        balancePaise: 50000, // 500 Rs bonus
      });
    }

    const response = await buildAuthResponse(user);
    user.lastLogin = new Date();
    await user.save();

    await Notification.create({
      userId: user._id,
      title: 'New Login Detected',
      message: 'A new login was detected on your account.',
      category: 'SYSTEM',
      priority: 'LOW'
    });

    res.status(200).json(response);
  } catch (error) {
    next(error);
  }
};

// @desc    Setup MPIN (first time, during onboarding)
// @route   POST /api/auth/setup-mpin
// @access  Private
const setupMpin = async (req, res, next) => {
  try {
    const { mpin } = req.body;

    if (!mpin || mpin.length < 4) {
      res.status(400);
      throw new Error('Valid MPIN is required');
    }

    const salt = await bcrypt.genSalt(10);
    const hashedMpin = await bcrypt.hash(mpin, salt);

    req.user.mpinHash = hashedMpin;
    await req.user.save();

    res.status(200).json({
      success: true,
      message: 'MPIN setup successful',
      data: { hasMpin: true },
    });
  } catch (error) {
    next(error);
  }
};


// @desc    Firebase Auth Login
// @route   POST /api/auth/firebase-login
// @access  Public
const firebaseLogin = async (req, res, next) => {
  try {
    console.time('firebaseLogin_total');
    console.log('[AUTH] Incoming firebase-login request');
    const { idToken } = req.body;

    if (!idToken) {
      res.status(400);
      throw new Error('No Firebase ID token provided');
    }

    let decodedToken;
    try {
      console.time('firebaseLogin_verifyToken');
      const app = getApp();
      decodedToken = await getAuth(app).verifyIdToken(idToken);
      console.timeEnd('firebaseLogin_verifyToken');
      console.log('[AUTH] Token verified successfully for UID:', decodedToken.uid);
    } catch (error) {
      console.error('Firebase ID token verification failed:', error.message);
      res.status(401);
      throw new Error('Invalid Firebase ID token: ' + error.message);
    }

    const { uid, phone_number } = decodedToken;

    if (!phone_number) {
      res.status(400);
      throw new Error('Firebase token does not contain a phone number');
    }

    // 1. Existing, fully-onboarded user → issue JWT + profile.
    let user = await User.findOne({ firebaseUid: uid });
    if (!user) {
      console.log('[AUTH] User not found by UID, falling back to phone lookup');
      user = await User.findOne({ phone: phone_number });
      if (user) {
        user.firebaseUid = uid;
      }
    }

    if (user) {
      user.lastLogin = new Date();
      await user.save();

      console.time('firebaseLogin_notification');
      await Notification.create({
        userId: user._id,
        title: 'New Login Detected',
        message: 'A new login was detected on your account.',
        category: 'SYSTEM',
        priority: 'LOW'
      });
      console.timeEnd('firebaseLogin_notification');

      console.log('[AUTH] User authenticated successfully. Returning session JWT.');
      console.time('firebaseLogin_buildResponse');
      const response = await buildAuthResponse(user);
      console.timeEnd('firebaseLogin_buildResponse');
      
      console.timeEnd('firebaseLogin_total');
      return res.status(200).json(response);
    }

    // 2. New user → tell the client to start onboarding. No JWT yet.
    console.timeEnd('firebaseLogin_total');
    return res.status(200).json({
      success: true,
      data: {
        isNewUser: true,
        phone: phone_number,
        firebaseUid: uid,
      },
    });
  } catch (error) {
    console.timeEnd('firebaseLogin_total');
    next(error);
  }
};

// @desc    Complete retailer onboarding / registration
// @route   POST /api/auth/register
// @access  Public (protected by Firebase ID token)
const registerRetailer = async (req, res, next) => {
  try {
    const { idToken } = req.body;

    if (!idToken) {
      res.status(400);
      throw new Error('No Firebase ID token provided');
    }

    let decodedToken;
    try {
      const app = getApp();
      decodedToken = await getAuth(app).verifyIdToken(idToken);
    } catch (error) {
      console.error('Firebase ID token verification failed:', error.message);
      res.status(401);
      throw new Error('Invalid Firebase ID token: ' + error.message);
    }

    const { uid, phone_number } = decodedToken;

    // Re-check: never double-create.
    let existing = await User.findOne({ firebaseUid: uid });
    if (!existing) existing = await User.findOne({ phone: phone_number });
    if (existing) {
      const response = await buildAuthResponse(existing);
      return res.status(200).json(response);
    }

    const {
      name,
      email,
      shopName,
      shopAddress,
      city,
      state,
      pincode,
      aadhaarNumber,
      panNumber,
      gstNumber,
      bank,
      mpin,
    } = req.body;

    if (!name || !mpin || !bank?.accountNumber || !bank?.ifsc) {
      res.status(422);
      throw new Error('Missing required registration fields');
    }

    const retailerId = await generateRetailerId();

    const salt = await bcrypt.genSalt(10);
    const hashedMpin = await bcrypt.hash(mpin, salt);

    const user = await User.create({
      retailerId,
      firebaseUid: uid,
      phone: phone_number,
      name: name.trim(),
      email: email ? email.trim().toLowerCase() : null,
      shopName: shopName?.trim() ?? null,
      shopAddress: shopAddress?.trim() ?? null,
      city: city?.trim() ?? null,
      state: state?.trim() ?? null,
      pincode: pincode?.trim() ?? null,
      aadhaarNumber: aadhaarNumber?.trim() ?? null,
      panNumber: panNumber?.trim().toUpperCase() ?? null,
      gstNumber: gstNumber?.trim().toUpperCase() ?? null,
      mpinHash: hashedMpin,
      kycStatus: 'pending',
      isOnboarded: true,
      isVerified: false,
    });

    await Bank.create({
      userId: user._id,
      accountHolderName: bank.accountHolderName?.trim(),
      bankName: bank.bankName?.trim(),
      accountNumber: bank.accountNumber?.trim(),
      ifsc: bank.ifsc?.trim().toUpperCase(),
    });

    await Kyc.create({
      userId: user._id,
      aadhaarNumber: aadhaarNumber?.trim() ?? null,
      panNumber: panNumber?.trim().toUpperCase() ?? null,
      gstNumber: gstNumber?.trim().toUpperCase() ?? null,
      status: 'pending',
      submittedAt: new Date(),
    });

    await Wallet.create({
      userId: user._id,
      balancePaise: 0,
    });

    user.lastLogin = new Date();
    await user.save();

    await Notification.create({
      userId: user._id,
      title: 'Welcome to A1 Recharge!',
      message: 'Your account has been created. Please complete your KYC to unlock all features.',
      category: 'INFO',
      priority: 'NORMAL',
      action: 'ROUTE_KYC'
    });

    const response = await buildAuthResponse(user);
    return res.status(201).json(response);
  } catch (error) {
    next(error);
  }
};

// @desc    Get current authenticated user's full profile
// @route   GET /api/auth/me
// @access  Private
const getMe = async (req, res, next) => {
  try {
    const [bank, wallet, kyc] = await Promise.all([
      Bank.findOne({ userId: req.user._id }),
      Wallet.findOne({ userId: req.user._id }),
      Kyc.findOne({ userId: req.user._id }),
    ]);

    res.status(200).json({
      success: true,
      data: buildProfile(req.user, bank, wallet, kyc),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Change MPIN via Firebase Phone Auth
// @route   PUT /api/user/change-mpin
// @access  Private
const changeMpin = async (req, res, next) => {
  try {
    const { idToken, newMpin } = req.body;
    
    if (!idToken || !newMpin) {
      return res.status(400).json({ success: false, message: 'Missing idToken or newMpin' });
    }

    if (newMpin.length !== 6 || !/^\d+$/.test(newMpin)) {
      return res.status(400).json({ success: false, message: 'MPIN must be exactly 6 digits.' });
    }

    if (/^(\d)\1+$/.test(newMpin)) {
      return res.status(400).json({ success: false, message: 'MPIN cannot contain repeating digits.' });
    }

    let decodedToken;
    try {
      const app = getApp();
      decodedToken = await getAuth(app).verifyIdToken(idToken);
    } catch (err) {
      return res.status(401).json({ success: false, message: 'Invalid or expired Firebase token.' });
    }

    // Ensure the token's phone number matches the user's registered phone
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    if (decodedToken.phone_number !== user.phone && decodedToken.uid !== user.firebaseUid) {
      return res.status(401).json({ success: false, message: 'Token does not match registered user.' });
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
      title: 'MPIN Changed',
      message: 'Your MPIN has been changed successfully. If you did not do this, contact support.',
      category: 'WARNING',
      priority: 'HIGH'
    });

    res.status(200).json({ success: true, message: 'MPIN updated successfully.' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  loginUser,
  verifyOtp,
  setupMpin,
  changeMpin,
  firebaseLogin,
  registerRetailer,
  getMe,
};
