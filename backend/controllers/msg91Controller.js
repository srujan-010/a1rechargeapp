const User = require('../models/User');
const Wallet = require('../models/Wallet');
const Bank = require('../models/Bank');
const Kyc = require('../models/Kyc');
const OtpSession = require('../models/OtpSession');
const generateRetailerId = require('../utils/generateRetailerId');
const jwt = require('jsonwebtoken');

// Generate backend JWT (session token) for a user id.
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: '30d',
  });
};

const TOKEN_TTL_DAYS = 30;

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
        Date.now() + TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000
      ).toISOString(),
      user: buildProfile(user, bank, wallet, kyc),
    },
  };
};

// @desc    Send OTP via MSG91
// @route   POST /api/msg91/send-otp
// @access  Public
const sendOtp = async (req, res, next) => {
  try {
    const { phone } = req.body;
    if (!phone) {
      res.status(400);
      throw new Error('Please include a phone number');
    }

    // Clean phone (assuming 10 digits without country code, MSG91 needs country code)
    const cleanPhone = phone.replace(/\D/g, '').slice(-10);

    let session = await OtpSession.findOne({ phone: cleanPhone });
    if (!session) {
      session = await OtpSession.create({ phone: cleanPhone });
    }

    // Check if blocked
    if (session.blockedUntil && session.blockedUntil > new Date()) {
      res.status(429);
      throw new Error(`Too many attempts. Try again after ${Math.ceil((session.blockedUntil - new Date()) / 60000)} minutes.`);
    }

    // Check rate limit: 5 requests per hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    if (session.lastRequestAt && session.lastRequestAt > oneHourAgo) {
      if (session.requestCount >= 5) {
        session.blockedUntil = new Date(Date.now() + 60 * 60 * 1000); // block for 1 hour
        await session.save();
        res.status(429);
        throw new Error('Maximum OTP limit reached for this hour. Try again later.');
      }
    } else {
      // Reset if more than an hour has passed
      session.requestCount = 0;
    }

    // Check 30-sec resend timer
    const thirtySecsAgo = new Date(Date.now() - 30 * 1000);
    if (session.lastRequestAt && session.lastRequestAt > thirtySecsAgo) {
      res.status(429);
      throw new Error('Please wait 30 seconds before requesting a new OTP.');
    }

    // Prepare MSG91 API Request
    const authKey = process.env.MSG91_AUTH_KEY;
    const templateId = process.env.MSG91_TEMPLATE_ID || 'TEMPLATE_ID_HERE';
    const mobileWithCode = `91${cleanPhone}`;

    const url = `https://control.msg91.com/api/v5/otp?template_id=${templateId}&mobile=${mobileWithCode}&authkey=${authKey}`;

    const msg91Options = {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    let msg91Response;
    try {
      const fetchResponse = await fetch(url, msg91Options);
      msg91Response = await fetchResponse.json();
    } catch (err) {
      console.error('MSG91 fetch error:', err);
      res.status(500);
      throw new Error('Failed to communicate with OTP provider.');
    }

    if (msg91Response.type === 'error') {
      console.error('MSG91 API error:', msg91Response);
      res.status(400);
      throw new Error(msg91Response.message || 'Failed to send OTP.');
    }

    // Update session
    session.requestCount += 1;
    session.lastRequestAt = new Date();
    session.verifyAttempts = 0; // Reset attempts on new OTP request
    await session.save();

    res.status(200).json({
      success: true,
      message: 'OTP sent successfully',
      data: { phone: cleanPhone }
    });

  } catch (error) {
    next(error);
  }
};

// @desc    Verify OTP via MSG91
// @route   POST /api/msg91/verify-otp
// @access  Public
const verifyOtp = async (req, res, next) => {
  try {
    const { phone, otp } = req.body;
    if (!phone || !otp) {
      res.status(400);
      throw new Error('Please provide phone and OTP');
    }

    const cleanPhone = phone.replace(/\D/g, '').slice(-10);

    const session = await OtpSession.findOne({ phone: cleanPhone });
    if (!session) {
      res.status(400);
      throw new Error('No OTP request found for this number.');
    }

    // Check if blocked
    if (session.blockedUntil && session.blockedUntil > new Date()) {
      res.status(429);
      throw new Error(`Too many attempts. Try again after ${Math.ceil((session.blockedUntil - new Date()) / 60000)} minutes.`);
    }

    // Enforce expiry (assuming MSG91 also enforces, but we do local check of 5 mins)
    const fiveMinsAgo = new Date(Date.now() - 5 * 60 * 1000);
    if (!session.lastRequestAt || session.lastRequestAt < fiveMinsAgo) {
      res.status(400);
      throw new Error('OTP expired. Please request a new one.');
    }

    // Check max attempts
    if (session.verifyAttempts >= 3) {
      session.blockedUntil = new Date(Date.now() + 15 * 60 * 1000); // block 15 min
      await session.save();
      res.status(429);
      throw new Error('Maximum verification attempts reached. Try again after 15 minutes.');
    }

    session.verifyAttempts += 1;
    await session.save();

    // Call MSG91 Verify API
    const authKey = process.env.MSG91_AUTH_KEY;
    const mobileWithCode = `91${cleanPhone}`;
    const url = `https://control.msg91.com/api/v5/otp/verify?otp=${otp}&mobile=${mobileWithCode}&authkey=${authKey}`;

    const msg91Options = {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    let msg91Response;
    try {
      const fetchResponse = await fetch(url, msg91Options);
      msg91Response = await fetchResponse.json();
    } catch (err) {
      console.error('MSG91 verify fetch error:', err);
      res.status(500);
      throw new Error('Failed to verify OTP with provider.');
    }

    if (msg91Response.type === 'error') {
      res.status(400);
      throw new Error(msg91Response.message || 'Invalid OTP');
    }

    // OTP Verified Successfully
    session.verifyAttempts = 0;
    session.requestCount = 0; // optionally reset on success
    await session.save();

    // Find or create user
    let user = await User.findOne({ phone: cleanPhone });

    if (!user) {
      const retailerId = await generateRetailerId();
      user = await User.create({
        phone: cleanPhone,
        name: `User ${cleanPhone.substring(6)}`,
        retailerId,
        kycStatus: 'verified', // or 'notStarted' depending on business logic, sticking to 'verified' to match firebase mock
        isVerified: true,
        isOnboarded: true,
      });

      await Bank.create({ userId: user._id });
      await Kyc.create({ userId: user._id, status: 'verified', submittedAt: new Date() });
      await Wallet.create({ userId: user._id, balancePaise: 0 });
    }

    user.lastLogin = new Date();
    await user.save();

    const response = await buildAuthResponse(user);
    res.status(200).json(response);

  } catch (error) {
    next(error);
  }
};

module.exports = {
  sendOtp,
  verifyOtp
};
