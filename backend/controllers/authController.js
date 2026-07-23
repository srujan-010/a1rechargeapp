const User = require('../models/User');
const Wallet = require('../models/Wallet');
const Bank = require('../models/Bank');
const Kyc = require('../models/Kyc');
const generateRetailerId = require('../utils/generateRetailerId');
const Notification = require('../models/Notification');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const axios = require('axios');
const { getApp } = require('../config/firebase');
const { getAuth } = require('firebase-admin/auth');

// Generate backend JWT (session token) for a user id.
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: '30d',
  });
};

const generateTempSessionToken = (phone) => {
  return jwt.sign({ phone }, process.env.JWT_SECRET, {
    expiresIn: '15m',
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
// @access  Public (Protected by tempSessionToken)
const registerRetailer = async (req, res, next) => {
  try {
    let token;
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }
    
    if (!token) {
      return res.status(401).json({ success: false, message: 'No session token provided for registration' });
    }

    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET);
    } catch (error) {
      return res.status(401).json({ success: false, message: 'Invalid or expired registration session token' });
    }

    const phone = decoded.phone;
    if (!phone) {
      return res.status(400).json({ success: false, message: 'Invalid session token payload' });
    }

    // Verify mobile is still unused
    const existing = await User.findOne({ phone });
    if (existing) {
      return res.status(400).json({ success: false, message: 'User already exists with this mobile number' });
    }

    const {
      name,
      shopName,
      email,
      address,
      state,
      district,
      pincode,
      referralCode
    } = req.body;

    if (!name || !shopName || !address) {
      return res.status(422).json({ success: false, message: 'Missing required registration fields' });
    }

    const retailerId = await generateRetailerId();

    const user = await User.create({
      retailerId,
      phone,
      name: name.trim(),
      email: email ? email.trim().toLowerCase() : null,
      shopName: shopName.trim(),
      shopAddress: address.trim(),
      city: district?.trim() ?? null,
      state: state?.trim() ?? null,
      pincode: pincode?.trim() ?? null,
      referredBy: referralCode?.trim() ?? null,
      kycStatus: 'notStarted',
      isOnboarded: false,
      isVerified: true,
      role: 'retailer',
      status: 'active'
    });

    const wallet = await Wallet.create({
      userId: user._id,
      balancePaise: 0,
    });

    const WalletLedger = require('../models/WalletLedger');
    await WalletLedger.create({
      userId: user._id,
      transactionType: 'CREDIT',
      amount: 0,
      balanceAfter: 0,
      referenceType: 'MANUAL',
      referenceId: user._id, // Using user ID as initial reference
      description: 'Account Created',
    });

    await Notification.create({
      userId: user._id,
      title: 'Welcome to A1 Recharge!',
      message: 'Your account has been created. Please complete your KYC to unlock all features.',
      category: 'INFO',
      priority: 'NORMAL',
      action: 'ROUTE_KYC'
    });

    const jwtToken = generateToken(user._id);
    
    // We don't have Bank or Kyc yet, but buildProfile expects them
    const bank = null;
    const kyc = null;
    const profile = buildProfile(user, bank, wallet, kyc);

    return res.status(201).json({
      success: true,
      token: jwtToken,
      user: profile,
    });
  } catch (error) {
    console.error('[REGISTRATION ERROR]', error);
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

// @desc    Authenticate/Register user via MSG91 OTP Widget v5 Access Token
// @route   POST /api/auth/msg91-login
// @access  Public
const msg91Login = async (req, res, next) => {
  const reqId = Math.random().toString(36).substring(7);
  console.log(`[MSG91 LOGIN][${reqId}] 🏁 Request started`);
  console.time(`msg91Login_total_${reqId}`);

  try {
    const { accessToken } = req.body;

    if (!accessToken) {
      console.log(`[MSG91 LOGIN][${reqId}] ❌ Missing accessToken`);
      return res.status(400).json({
        success: false,
        message: 'accessToken is required',
      });
    }

    const authKey = process.env.MSG91_AUTH_KEY;
    const maskedAuthKey = authKey ? authKey.substring(0, 6) + '*'.repeat(authKey.length - 6) : 'NO_KEY';
    
    console.log('════════════════════════════════════════════════════════════════');
    console.log(`[MSG91 LOGIN][${reqId}] Incoming Flutter Request Body:`, JSON.stringify(req.body));
    console.log(`[MSG91 LOGIN][${reqId}] Auth Key configured: ` + (authKey ? 'YES' : 'NO') + ' (Masked: ' + maskedAuthKey + ')');

    if (!authKey) {
      console.log(`[MSG91 LOGIN][${reqId}] ❌ MSG91_AUTH_KEY missing`);
      return res.status(500).json({
        success: false,
        message: 'MSG91_AUTH_KEY is not configured on server',
      });
    }

    const msg91Url = 'https://api.msg91.com/api/v5/widget/verifyAccessToken';
    const msg91Payload = { 'access-token': accessToken };
    const msg91Headers = {
      'Content-Type': 'application/json',
      'authkey': authKey
    };

    console.log(`[MSG91 LOGIN][${reqId}] POST URL:`, msg91Url);
    console.log(`[MSG91 LOGIN][${reqId}] Request Headers:`, JSON.stringify({ ...msg91Headers, 'authkey': maskedAuthKey }));
    
    let msg91Response;
    try {
      console.log(`[MSG91 LOGIN][${reqId}] ⏳ Calling MSG91 API...`);
      console.time(`msg91_api_call_${reqId}`);
      
      msg91Response = await axios.post(
        msg91Url,
        msg91Payload,
        { 
          headers: msg91Headers,
          timeout: 8000 // 8 second timeout to prevent hanging forever
        }
      );
      
      console.timeEnd(`msg91_api_call_${reqId}`);
      console.log(`[MSG91 LOGIN][${reqId}] ✅ MSG91 API returned successfully`);
    } catch (error) {
      console.timeEnd(`msg91_api_call_${reqId}`);
      console.log(`[MSG91 LOGIN][${reqId}] ❌ Axios Error making MSG91 request:`, error.message);
      
      if (error.code === 'ECONNABORTED' || error.message.includes('timeout')) {
         return res.status(504).json({
            success: false,
            message: 'Gateway Timeout: MSG91 API took too long to respond'
         });
      }

      if (error.response) {
         msg91Response = error.response; 
      } else {
         throw error;
      }
    }

    const msgData = msg91Response.data || {};
    
    console.log(`[MSG91 LOGIN][${reqId}] MSG91 verification HTTP Status:`, msg91Response.status);
    console.log(`[MSG91 LOGIN][${reqId}] MSG91 verification Response Headers:`, JSON.stringify(msg91Response.headers));
    
    const isSuccess = 
       msgData.type === 'success' || 
       msgData.status === 'success' || 
       msgData.success === true || 
       msgData.code === 200 || 
       msgData.code === 201 ||
       (msgData.message && typeof msgData.message === 'string' && msgData.message.toLowerCase().includes('success'));

    if (!isSuccess) {
       console.log(`[MSG91 LOGIN][${reqId}] ❌ Verification failed. Returning raw response to Flutter.`);
       return res.status(401).json({
         success: false,
         debugResponse: msgData, 
         message: msgData.message || 'Verification failed (see debugResponse)'
       });
    }

    const findPhone = (obj) => {
       if (!obj || typeof obj !== 'object') return null;
       for (const key of Object.keys(obj)) {
          const val = obj[key];
          if (typeof val === 'string' || typeof val === 'number') {
             let strVal = String(val).replace(/\D/g, '');
             if (strVal.length === 10) return strVal;
             if (strVal.length > 10 && strVal.startsWith('91')) {
                strVal = strVal.slice(-10);
                if (strVal.length === 10) return strVal;
             }
          } else if (typeof val === 'object') {
             const found = findPhone(val);
             if (found) return found;
          }
       }
       return null;
    };

    const phone = findPhone(msgData);

    if (!phone) {
       console.log(`[MSG91 LOGIN][${reqId}] ❌ Phone number not found in successful response.`);
       return res.status(400).json({
         success: false,
         message: 'Verification succeeded but phone number could not be extracted',
         debugResponse: msgData
       });
    }

    console.log(`[MSG91 LOGIN][${reqId}] ✅ Verified phone number extracted: ${phone}`);
    console.log(`[MSG91 LOGIN][${reqId}] ⏳ Querying MongoDB for user...`);
    console.time(`mongodb_query_${reqId}`);

    let user = await User.findOne({ phone }).maxTimeMS(5000);

    if (!user) {
      console.log(`[MSG91 LOGIN][${reqId}] User not found for phone ${phone}. Returning tempSessionToken for registration.`);
      const tempSessionToken = generateTempSessionToken(phone);
      
      console.timeEnd(`mongodb_query_${reqId}`);
      console.timeEnd(`msg91Login_total_${reqId}`);
      console.log(`[MSG91 LOGIN][${reqId}] 🏁 Request successfully completed (New User).`);
      
      return res.status(200).json({
        success: true,
        isNewUser: true,
        mobile: phone,
        tempSessionToken,
      });
    }

    user.lastLogin = new Date();
    await user.save();

    await Notification.create({
      userId: user._id,
      title: 'New Login Detected',
      message: 'Logged in via MSG91 OTP Widget.',
      category: 'SYSTEM',
      priority: 'LOW',
    });

    const jwtToken = generateToken(user._id);

    const [bank, wallet, kyc] = await Promise.all([
      Bank.findOne({ userId: user._id }).maxTimeMS(5000),
      Wallet.findOne({ userId: user._id }).maxTimeMS(5000),
      Kyc.findOne({ userId: user._id }).maxTimeMS(5000),
    ]);
    
    console.timeEnd(`mongodb_query_${reqId}`);
    console.log(`[MSG91 LOGIN][${reqId}] ✅ MongoDB operations completed`);

    const profile = buildProfile(user, bank, wallet, kyc);

    console.timeEnd(`msg91Login_total_${reqId}`);
    console.log(`[MSG91 LOGIN][${reqId}] 🏁 Request successfully completed (Existing User). Sending response.`);

    return res.status(200).json({
      success: true,
      isNewUser: false,
      token: jwtToken,
      user: profile,
    });
  } catch (error) {
    console.timeEnd(`msg91Login_total_${reqId}`);
    console.error(`[MSG91 LOGIN][${reqId}] ❌ Unexpected Server Error:`, error);
    if (!res.headersSent) {
      return res.status(500).json({
        success: false,
        message: 'Internal Server Error during MSG91 login',
        error: error.message
      });
    }
    next(error);
  }
};

module.exports = {
  loginUser,
  verifyOtp,
  firebaseLogin,
  registerRetailer,
  getMe,
  msg91Login,
};
