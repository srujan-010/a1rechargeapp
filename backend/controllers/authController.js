const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const Bank = require('../models/Bank');
const Kyc = require('../models/Kyc');
const Otp = require('../models/Otp');
const Notification = require('../models/Notification');
const notificationService = require('../services/notification.service');
const generateRetailerId = require('../utils/generateRetailerId');
const fast2smsService = require('../services/fast2sms.service');
const admin = require('firebase-admin');
const { getApp } = require('../config/firebase');
const reviewerService = require('../services/reviewer.service');

// Configuration Constants
const OTP_EXPIRY_MINUTES = parseInt(process.env.OTP_EXPIRY_MINUTES || '10', 10);
const OTP_MAX_ATTEMPTS = parseInt(process.env.OTP_MAX_ATTEMPTS || '5', 10);
const OTP_MAX_RESEND = parseInt(process.env.OTP_MAX_RESEND || '5', 10);
const OTP_COOLDOWN_SECONDS = parseInt(process.env.OTP_COOLDOWN_SECONDS || '30', 10);
const OTP_MAX_REQUESTS_PER_HOUR = parseInt(process.env.OTP_MAX_REQUESTS_PER_HOUR || '5', 10);
const TOKEN_TTL_DAYS = 30;

// Clean phone number to 10 digits
const cleanMobile = (rawMobile) => {
  if (!rawMobile) return '';
  let cleaned = String(rawMobile).replace(/\D/g, '');
  if (cleaned.length > 10 && cleaned.startsWith('91')) {
    cleaned = cleaned.slice(-10);
  }
  return cleaned;
};

// Generate backend JWT for session
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: '30d',
  });
};

// Generate temp session token for onboarding/registration
const generateTempSessionToken = (phone) => {
  return jwt.sign({ phone }, process.env.JWT_SECRET, {
    expiresIn: '15m',
  });
};

// Build profile response
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

// Compose standard success response
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
      token: generateToken(user._id),
      expiresAt: new Date(
        Date.now() + TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000
      ).toISOString(),
      user: buildProfile(user, bank, wallet, kyc),
    },
  };
};

/**
/**
 * @desc    Send OTP via Fast2SMS WhatsApp Template API (Login OTP)
 * @route   POST /api/auth/send-otp
 * @access  Public
 */
const sendOtp = async (req, res, next) => {
  try {
    const rawMobile = req.body.mobile || req.body.phone;
    const mobile = cleanMobile(rawMobile);

    if (!mobile || mobile.length !== 10) {
      res.status(400);
      throw new Error('Please provide a valid 10-digit mobile number.');
    }

    // Google Play Reviewer Authentication Path (Server-Side Only)
    if (reviewerService.isReviewerPhone(mobile)) {
      return await reviewerService.handleReviewerSendOtp(res, mobile);
    }

    // Rate Limiting: Max 5 requests per hour per mobile for login
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recentRequestsCount = await Otp.countDocuments({
      mobile,
      purpose: 'login',
      createdAt: { $gte: oneHourAgo },
    });

    if (recentRequestsCount >= OTP_MAX_REQUESTS_PER_HOUR) {
      res.status(429);
      throw new Error(`Maximum OTP requests (${OTP_MAX_REQUESTS_PER_HOUR}) per hour reached. Please try again later.`);
    }

    // Generate secure 6-digit random OTP
    const otp = crypto.randomInt(100000, 1000000).toString();

    // Hash OTP before saving
    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otp, salt);

    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    // Delete any existing login OTP for this mobile
    await Otp.deleteMany({ mobile, purpose: 'login' });

    // Save OTP to MongoDB
    const storedOtpRecord = await Otp.create({
      mobile,
      purpose: 'login',
      otpHash,
      expiresAt,
      attempts: 0,
      resendCount: 0,
      lastSentAt: new Date(),
    });

    console.log('════════════════════════════════════════════════════════════════');
    console.log('[SEND LOGIN OTP LOGS]');
    console.log(`- Cleaned Mobile Number: ${mobile.length === 10 ? '******' + mobile.slice(-4) : mobile}`);
    console.log(`- Purpose: LOGIN_OTP`);
    console.log(`- Stored OTP Hash: ${otpHash}`);
    console.log(`- MongoDB Save Result ID: ${storedOtpRecord._id}`);
    console.log(`- Expiry Time: ${expiresAt.toISOString()}`);

    // Send Login OTP via Fast2SMS WhatsApp API
    const fast2smsResult = await fast2smsService.sendLoginOtp({ mobile, otp });
    console.log(`- Fast2SMS Send Result:`, JSON.stringify(fast2smsResult, null, 2));
    console.log('════════════════════════════════════════════════════════════════');

    res.status(200).json({
      success: true,
      message: 'OTP sent successfully on WhatsApp.',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Verify OTP sent via Fast2SMS WhatsApp (Login OTP)
 * @route   POST /api/auth/verify-otp
 * @access  Public
 */
const verifyOtp = async (req, res, next) => {
  try {
    const rawMobile = req.body.mobile || req.body.phone;
    const { otp } = req.body;

    const mobile = cleanMobile(rawMobile);
    const enteredOtp = String(otp || '').trim();

    const maskedMobile = mobile.length === 10 ? `******${mobile.slice(-4)}` : mobile;

    console.log('════════════════════════════════════════════════════════════════');
    console.log('[VERIFY LOGIN OTP LOGS]');
    console.log(`- Cleaned Mobile Number: ${maskedMobile}`);
    console.log(`- Purpose: LOGIN_OTP`);

    if (!mobile || mobile.length !== 10) {
      console.error(`[VERIFY OTP FAILURE REASON]: Invalid Mobile Number (${rawMobile})`);
      res.status(400);
      throw new Error('Please provide a valid 10-digit mobile number.');
    }

    if (!enteredOtp || enteredOtp.length !== 6) {
      console.error(`[VERIFY OTP FAILURE REASON]: Invalid OTP length`);
      res.status(400);
      throw new Error('Please enter a valid 6-digit OTP.');
    }

    // Google Play Reviewer Verification Path (Server-Side Only)
    if (reviewerService.isReviewerPhone(mobile)) {
      return await reviewerService.handleReviewerVerifyOtp(req, res, mobile, enteredOtp);
    }

    const otpRecord = await Otp.findOne({ mobile, purpose: 'login' });

    if (!otpRecord) {
      console.error(`[VERIFY OTP FAILURE REASON]: OTP Record Not Found in MongoDB for mobile: ${maskedMobile} with purpose: login`);
      res.status(400);
      throw new Error('OTP has expired or is invalid. Please request a new OTP.');
    }

    console.log(`- Found MongoDB OTP Record ID: ${otpRecord._id}`);
    console.log(`- Stored Hash in DB: ${otpRecord.otpHash}`);
    console.log(`- Current Attempts: ${otpRecord.attempts}/${OTP_MAX_ATTEMPTS}`);
    console.log(`- Expires At: ${otpRecord.expiresAt.toISOString()} (Current: ${new Date().toISOString()})`);

    if (otpRecord.expiresAt < new Date()) {
      console.error(`[VERIFY OTP FAILURE REASON]: OTP Expired`);
      await Otp.deleteOne({ _id: otpRecord._id });
      res.status(400);
      throw new Error('OTP has expired. Please request a new OTP.');
    }

    if (otpRecord.attempts >= OTP_MAX_ATTEMPTS) {
      console.error(`[VERIFY OTP FAILURE REASON]: Max Attempts Exceeded (${otpRecord.attempts})`);
      await Otp.deleteOne({ _id: otpRecord._id });
      res.status(400);
      throw new Error('Maximum verification attempts exceeded. Please request a new OTP.');
    }

    // Verify OTP hash
    const isMatch = await bcrypt.compare(enteredOtp, otpRecord.otpHash);
    console.log(`- bcrypt.compare() Match Result: ${isMatch}`);

    if (!isMatch) {
      console.error(`[VERIFY OTP FAILURE REASON]: Hash Mismatch`);
      otpRecord.attempts += 1;
      await otpRecord.save();

      const attemptsLeft = OTP_MAX_ATTEMPTS - otpRecord.attempts;
      if (attemptsLeft <= 0) {
        await Otp.deleteOne({ _id: otpRecord._id });
        res.status(400);
        throw new Error('Maximum verification attempts exceeded. Please request a new OTP.');
      }

      res.status(400);
      throw new Error(`Invalid OTP. ${attemptsLeft} attempt(s) remaining.`);
    }

    console.log('[VERIFY OTP SUCCESS]: Login OTP Verified successfully!');
    console.log('════════════════════════════════════════════════════════════════');

    // OTP Verified -> Delete OTP record
    await Otp.deleteOne({ _id: otpRecord._id });

    // Check if retailer exists in MongoDB
    let user = await User.findOne({
      $or: [
        { phone: mobile },
        { phone: `+91${mobile}` },
        { phone: `91${mobile}` }
      ]
    });

    if (user) {
      user.lastLogin = new Date();
      await user.save();

      notificationService.notifyLoginAlert({
        userId: user._id,
        ip: req.ip || req.connection.remoteAddress,
        device: req.headers['user-agent']
      });

      const response = await buildAuthResponse(user);
      return res.status(200).json(response);
    } else {
      // New Retailer -> Return temporary session token for registration
      const tempSessionToken = generateTempSessionToken(mobile);
      return res.status(200).json({
        success: true,
        isNewUser: true,
        mobile,
        tempSessionToken,
      });
    }
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Resend OTP via Fast2SMS WhatsApp (Login OTP)
 * @route   POST /api/auth/resend-otp
 * @access  Public
 */
const resendOtp = async (req, res, next) => {
  try {
    const rawMobile = req.body.mobile || req.body.phone;
    const mobile = cleanMobile(rawMobile);

    if (!mobile || mobile.length !== 10) {
      res.status(400);
      throw new Error('Please provide a valid 10-digit mobile number.');
    }

    // Google Play Reviewer Resend Path (Server-Side Only)
    if (reviewerService.isReviewerPhone(mobile)) {
      return await reviewerService.handleReviewerSendOtp(res, mobile);
    }

    const otpRecord = await Otp.findOne({ mobile, purpose: 'login' });

    if (!otpRecord) {
      // If no active OTP record found, generate a fresh one via sendOtp logic
      return sendOtp(req, res, next);
    }

    // Cooldown check (30 seconds)
    const timeSinceLastSent = (Date.now() - otpRecord.lastSentAt.getTime()) / 1000;
    if (timeSinceLastSent < OTP_COOLDOWN_SECONDS) {
      const waitTime = Math.ceil(OTP_COOLDOWN_SECONDS - timeSinceLastSent);
      res.status(429);
      throw new Error(`Please wait ${waitTime} second(s) before requesting another OTP resend.`);
    }

    // Resend limit check
    if (otpRecord.resendCount >= OTP_MAX_RESEND) {
      res.status(429);
      throw new Error(`Maximum resend limit (${OTP_MAX_RESEND}) reached. Please try again later.`);
    }

    // Generate new OTP
    const otp = crypto.randomInt(100000, 1000000).toString();
    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otp, salt);

    otpRecord.otpHash = otpHash;
    otpRecord.expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);
    otpRecord.resendCount += 1;
    otpRecord.attempts = 0;
    otpRecord.lastSentAt = new Date();
    await otpRecord.save();

    // Send new OTP via Fast2SMS WhatsApp API
    await fast2smsService.sendLoginOtp({ mobile, otp });

    res.status(200).json({
      success: true,
      message: 'OTP resent successfully on WhatsApp.',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Complete retailer onboarding / registration
 * @route   POST /api/auth/register
 * @access  Public (Protected by tempSessionToken)
 */
/**
 * @desc    Complete retailer/personal onboarding / registration
 * @route   POST /api/auth/register
 * @access  Public (Protected by tempSessionToken)
 */
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

    const cleanedPhone = cleanMobile(phone);

    const {
      accountType,
      name,
      shopName,
      hasPhysicalShop,
      businessType,
      email,
      address,
      state,
      district,
      pincode,
      referralCode,
      termsAccepted,
    } = req.body;

    const normalizedAccountType = (accountType || 'RETAILER').toString().trim().toUpperCase() === 'PERSONAL'
      ? 'PERSONAL'
      : 'RETAILER';

    if (!name || String(name).trim().length === 0) {
      return res.status(422).json({ success: false, message: 'Full Name is required for onboarding' });
    }

    const parsedHasPhysicalShop = normalizedAccountType === 'PERSONAL'
      ? false
      : (hasPhysicalShop !== false && hasPhysicalShop !== 'false');

    const parsedBusinessType = normalizedAccountType === 'RETAILER'
      ? (businessType && String(businessType).trim().length > 0 ? String(businessType).trim() : 'Mobile Recharge Shop')
      : null;

    if (normalizedAccountType === 'RETAILER') {
      if (!shopName || String(shopName).trim().length === 0) {
        return res.status(422).json({ success: false, message: 'Business / Shop Name is required for Retailer account' });
      }
      if (parsedHasPhysicalShop && (!address || String(address).trim().length === 0)) {
        return res.status(422).json({ success: false, message: 'Physical shop address is required when Physical Shop is YES' });
      }
    }

    // Verify mobile is unused or onboarding incomplete
    let user = await User.findOne({
      $or: [
        { phone: cleanedPhone },
        { phone: `+91${cleanedPhone}` }
      ]
    });

    if (user && user.isOnboarded) {
      return res.status(400).json({ success: false, message: 'User already exists with this mobile number' });
    }

    const formattedName = String(name).trim();
    const formattedEmail = email ? String(email).trim().toLowerCase() : null;
    const formattedShopName = normalizedAccountType === 'RETAILER' ? String(shopName).trim() : null;
    const formattedAddress = address ? String(address).trim() : null;
    const formattedBusinessType = parsedBusinessType;

    if (!user) {
      const retailerId = await generateRetailerId();
      user = await User.create({
        retailerId,
        phone: cleanedPhone,
        accountType: normalizedAccountType,
        name: formattedName,
        email: formattedEmail,
        shopName: formattedShopName,
        hasPhysicalShop: parsedHasPhysicalShop,
        businessType: formattedBusinessType,
        shopAddress: formattedAddress,
        city: district?.trim() ?? null,
        state: state?.trim() ?? null,
        pincode: pincode?.trim() ?? null,
        referredBy: referralCode?.trim() ?? null,
        kycStatus: 'notStarted',
        isOnboarded: true,
        isVerified: true,
        role: 'retailer',
        status: 'active',
        termsAccepted: termsAccepted !== false,
        termsAcceptedAt: new Date(),
      });
    } else {
      user.accountType = normalizedAccountType;
      user.name = formattedName;
      user.email = formattedEmail;
      user.shopName = formattedShopName;
      user.hasPhysicalShop = parsedHasPhysicalShop;
      user.businessType = formattedBusinessType;
      if (formattedAddress) user.shopAddress = formattedAddress;
      if (district) user.city = district.trim();
      if (state) user.state = state.trim();
      if (pincode) user.pincode = pincode.trim();
      user.isOnboarded = true;
      user.termsAccepted = termsAccepted !== false;
      user.termsAcceptedAt = new Date();
      await user.save();
    }

    let wallet = await Wallet.findOne({ userId: user._id });
    if (!wallet) {
      wallet = await Wallet.create({
        userId: user._id,
        balancePaise: 0,
      });

      const WalletLedger = require('../models/WalletLedger');
      await WalletLedger.create({
        userId: user._id,
        transactionType: 'CREDIT',
        amountPaise: 0,
        previousBalancePaise: 0,
        balanceAfterPaise: 0,
        amount: 0,
        previousBalance: 0,
        balanceAfter: 0,
        referenceType: 'MANUAL',
        referenceId: user._id,
        description: 'Account Created',
      });
    }

    notificationService.notifyOnboardingSuccess({ userId: user._id });

    // ONE-TIME Welcome WhatsApp Message for New User Onboarding
    (async () => {
      try {
        console.log('\n[WELCOME_WHATSAPP] New user detected: true');
        console.log(`[WELCOME_WHATSAPP] Onboarding completed for user: ${user._id}`);

        if (user.welcomeWhatsAppSent) {
          console.log(`[WELCOME_WHATSAPP] Welcome message already sent for user ${user._id}. Skipping.`);
          return;
        }

        const result = await fast2smsService.sendWelcomeTemplate({
          name: user.name,
          mobile: user.phone,
        });

        if (result.success) {
          user.welcomeWhatsAppSent = true;
          user.welcomeWhatsAppSentAt = new Date();
          user.welcomeWhatsAppMessageId = '30063';
          user.welcomeWhatsAppStatus = 'SENT';
          await user.save().catch(e => console.error('[WELCOME_WHATSAPP SAVE ERROR]:', e.message));
        } else {
          user.welcomeWhatsAppStatus = 'FAILED';
          await user.save().catch(e => console.error('[WELCOME_WHATSAPP SAVE ERROR]:', e.message));
        }
      } catch (wErr) {
        console.error('[WELCOME_WHATSAPP ASYNC ERROR]:', wErr.message);
      }
    })();

    const jwtToken = generateToken(user._id);

    const bank = null;
    const kyc = null;
    const profile = buildProfile(user, bank, wallet, kyc);

    return res.status(201).json({
      success: true,
      token: jwtToken,
      accessToken: jwtToken,
      user: profile,
    });
  } catch (error) {
    console.error('[REGISTRATION ERROR]', error);
    next(error);
  }
};

/**
 * @desc    Get current authenticated user's full profile
 * @route   GET /api/auth/me
 * @access  Private
 */
const getMe = async (req, res, next) => {
  try {
    const [bank, wallet, kyc] = await Promise.all([
      Bank.findOne({ userId: req.user._id }).lean().maxTimeMS(3000),
      Wallet.findOne({ userId: req.user._id }).lean().maxTimeMS(3000),
      Kyc.findOne({ userId: req.user._id }).lean().maxTimeMS(3000),
    ]);

    res.status(200).json({
      success: true,
      data: buildProfile(req.user, bank, wallet, kyc),
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Firebase Auth Login (Fallback)
 * @route   POST /api/auth/firebase-login
 * @access  Public
 */
const firebaseLogin = async (req, res, next) => {
  try {
    const { idToken } = req.body;

    if (!idToken) {
      res.status(400);
      throw new Error('No Firebase ID token provided');
    }

    let decodedToken;
    try {
      const app = getApp();
      decodedToken = await admin.auth(app).verifyIdToken(idToken);
    } catch (error) {
      res.status(401);
      throw new Error('Invalid Firebase ID token: ' + error.message);
    }

    const { uid, phone_number } = decodedToken;

    if (!phone_number) {
      res.status(400);
      throw new Error('Firebase token does not contain a phone number');
    }

    let user = await User.findOne({ firebaseUid: uid });
    if (!user) {
      const cleaned = cleanMobile(phone_number);
      user = await User.findOne({ phone: cleaned });
      if (user) {
        user.firebaseUid = uid;
      }
    }

    if (user) {
      user.lastLogin = new Date();
      await user.save();

      const response = await buildAuthResponse(user);
      return res.status(200).json(response);
    }

    return res.status(200).json({
      success: true,
      data: {
        isNewUser: true,
        phone: phone_number,
        firebaseUid: uid,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  sendOtp,
  verifyOtp,
  resendOtp,
  registerRetailer,
  getMe,
  firebaseLogin,
};
