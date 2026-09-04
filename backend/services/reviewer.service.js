const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const Transaction = require('../models/Transaction');
const RechargeTransaction = require('../models/RechargeTransaction');
const Otp = require('../models/Otp');
const Bank = require('../models/Bank');
const Kyc = require('../models/Kyc');

// In-memory rate limiting state for reviewer OTP requests to prevent abuse
const reviewerRateLimitState = {
  requests: [], // timestamps of send-otp calls
  lastSentAt: null,
};

const REVIEWER_HOURLY_LIMIT = 15;
const REVIEWER_COOLDOWN_SECONDS = 10;
const REVIEWER_MAX_VERIFY_ATTEMPTS = 5;

// Clean phone number to 10 digits
const cleanMobile = (rawMobile) => {
  if (!rawMobile) return '';
  let cleaned = String(rawMobile).replace(/\D/g, '');
  if (cleaned.length > 10 && cleaned.startsWith('91')) {
    cleaned = cleaned.slice(-10);
  }
  return cleaned;
};

class ReviewerService {
  /**
   * Check if Reviewer Mode is active.
   * Both GOOGLE_PLAY_REVIEWER_PHONE and GOOGLE_PLAY_REVIEWER_OTP MUST be configured.
   * Absolutely NO default or predictable values.
   */
  isReviewerEnabled() {
    const phone = process.env.GOOGLE_PLAY_REVIEWER_PHONE;
    const otp = process.env.GOOGLE_PLAY_REVIEWER_OTP;
    return !!(phone && String(phone).trim().length >= 10 && otp && String(otp).trim().length >= 4);
  }

  /**
   * Returns cleaned 10-digit reviewer phone or null
   */
  getReviewerPhone() {
    if (!this.isReviewerEnabled()) return null;
    return cleanMobile(process.env.GOOGLE_PLAY_REVIEWER_PHONE);
  }

  /**
   * Returns configured secret OTP or null (Strictly NO default/fallback)
   */
  getReviewerOtp() {
    if (!this.isReviewerEnabled()) return null;
    const otp = process.env.GOOGLE_PLAY_REVIEWER_OTP;
    return otp ? String(otp).trim() : null;
  }

  /**
   * Returns configured reviewer PIN or null (Strictly NO default/fallback)
   */
  getReviewerPin() {
    const pin = process.env.GOOGLE_PLAY_REVIEWER_PIN;
    return pin ? String(pin).trim() : null;
  }

  /**
   * Check if a given mobile matches the configured reviewer phone
   */
  isReviewerPhone(mobile) {
    const reviewerPhone = this.getReviewerPhone();
    if (!reviewerPhone) return false;
    const cleaned = cleanMobile(mobile);
    return cleaned === reviewerPhone;
  }

  /**
   * Check if a given user object belongs to the reviewer
   */
  isReviewerUser(user) {
    if (!user) return false;
    const reviewerPhone = this.getReviewerPhone();
    if (reviewerPhone && cleanMobile(user.phone) === reviewerPhone) {
      return true;
    }
    return user.isTestAccount === true && user.retailerId === 'RET_PLAY_TEST';
  }

  /**
   * Check if a given userId belongs to the reviewer
   */
  async isReviewerUserId(userId) {
    if (!userId || !this.isReviewerEnabled()) return false;
    try {
      const user = await User.findById(userId).lean();
      return this.isReviewerUser(user);
    } catch {
      return false;
    }
  }

  /**
   * Multi-format check for existing user conflict.
   * If an existing non-test production account uses this phone: STOP IMMEDIATELY.
   */
  async checkExistingUserConflict(reviewerPhone) {
    const cleanedPhone = cleanMobile(reviewerPhone);
    if (!cleanedPhone) return null;

    const existingUser = await User.findOne({
      $or: [
        { phone: cleanedPhone },
        { phone: `+91${cleanedPhone}` },
        { phone: `91${cleanedPhone}` },
        { phone: `+91 ${cleanedPhone}` },
        { phone: new RegExp(cleanedPhone + '$') },
      ],
    });

    if (existingUser) {
      const isReviewerTest = existingUser.isTestAccount === true || existingUser.retailerId === 'RET_PLAY_TEST';
      if (!isReviewerTest) {
        console.error(`[CRITICAL CONFLICT] GOOGLE_PLAY_REVIEWER_PHONE (${cleanedPhone}) conflicts with existing production user: ${existingUser._id} (${existingUser.role || 'user'}). Aborting reviewer setup to protect customer data.`);
        throw new Error('Configured reviewer phone conflicts with an existing production account. Cannot proceed.');
      }
      return existingUser;
    }

    return null;
  }

  /**
   * Idempotently provision or fetch the Reviewer Account.
   * Ensures account exists only if no production conflict.
   */
  async ensureReviewerAccount() {
    const reviewerPhone = this.getReviewerPhone();
    if (!reviewerPhone) {
      throw new Error('Reviewer mode is not enabled or phone number is missing.');
    }

    // 1. Conflict check across all phone formats
    let user = await this.checkExistingUserConflict(reviewerPhone);

    const reviewerPin = this.getReviewerPin();
    let hashedPin = null;
    if (reviewerPin) {
      const salt = await bcrypt.genSalt(10);
      hashedPin = await bcrypt.hash(reviewerPin, salt);
    }

    if (!user) {
      console.log(`[REVIEWER SETUP] Provisioning isolated Google Play Reviewer account for mobile: ******${reviewerPhone.slice(-4)}`);
      user = await User.create({
        retailerId: 'RET_PLAY_TEST',
        phone: reviewerPhone,
        name: 'Google Play Reviewer',
        email: 'play-reviewer@test.a1recharge.com',
        role: 'retailer',
        accountType: 'RETAILER',
        isOnboarded: true,
        isVerified: true,
        status: 'active',
        hasPhysicalShop: false,
        businessType: 'Testing / Reviewer Sandbox',
        shopName: 'A1 Recharge Play Reviewer Sandbox',
        shopAddress: 'Reviewer Sandbox Environment',
        city: 'Reviewer Test City',
        state: 'Reviewer Test State',
        pincode: '000000',
        aadhaarNumber: null, // Zero fake government ID
        panNumber: null,     // Zero fake government ID
        gstNumber: null,     // Zero fake government ID
        kycStatus: 'notStarted',
        isTestAccount: true,
        securityPinHash: hashedPin,
        walletMpinHash: hashedPin,
        termsAccepted: true,
        termsAcceptedAt: new Date(),
      });
    } else {
      // Update PIN hashes if configured and not yet set
      let needsSave = false;
      if (hashedPin && (!user.securityPinHash || !user.walletMpinHash)) {
        if (!user.securityPinHash) user.securityPinHash = hashedPin;
        if (!user.walletMpinHash) user.walletMpinHash = hashedPin;
        needsSave = true;
      }
      if (!user.isTestAccount) {
        user.isTestAccount = true;
        needsSave = true;
      }
      if (needsSave) await user.save();
    }

    // 2. Ensure Isolated Reviewer Test Wallet exists with controlled balance
    let wallet = await Wallet.findOne({ userId: user._id });
    if (!wallet) {
      wallet = await Wallet.create({
        userId: user._id,
        balancePaise: 250000, // ₹2,500.00 controlled test balance
        onHoldPaise: 0,
        currency: 'INR',
      });

      await WalletLedger.create({
        userId: user._id,
        transactionType: 'CREDIT',
        amountPaise: 250000,
        previousBalancePaise: 0,
        balanceAfterPaise: 250000,
        amount: 2500,
        previousBalance: 0,
        balanceAfter: 2500,
        referenceType: 'MANUAL',
        referenceId: user._id,
        description: 'Initial Controlled Test Wallet Allocation',
        remark: 'REVIEWER_TEST_SEED',
      });
    }

    // 3. Ensure test Kyc record is clearly marked as sandbox
    let kyc = await Kyc.findOne({ userId: user._id });
    if (!kyc) {
      await Kyc.create({
        userId: user._id,
        status: 'notStarted',
        remarks: 'Google Play Reviewer Sandbox Account - No real financial identity required',
        isTestAccount: true,
      });
    }

    return user;
  }

  /**
   * Enforces dedicated rate limiting for reviewer OTP requests.
   */
  checkReviewerRateLimit() {
    const now = Date.now();
    const oneHourAgo = now - 60 * 60 * 1000;

    // Filter requests older than 1 hour
    reviewerRateLimitState.requests = reviewerRateLimitState.requests.filter(ts => ts > oneHourAgo);

    if (reviewerRateLimitState.lastSentAt) {
      const elapsedSeconds = (now - reviewerRateLimitState.lastSentAt) / 1000;
      if (elapsedSeconds < REVIEWER_COOLDOWN_SECONDS) {
        const wait = Math.ceil(REVIEWER_COOLDOWN_SECONDS - elapsedSeconds);
        const err = new Error(`Please wait ${wait} second(s) before requesting another OTP.`);
        err.statusCode = 429;
        throw err;
      }
    }

    if (reviewerRateLimitState.requests.length >= REVIEWER_HOURLY_LIMIT) {
      const err = new Error(`Maximum reviewer OTP requests (${REVIEWER_HOURLY_LIMIT}) per hour reached.`);
      err.statusCode = 429;
      throw err;
    }

    reviewerRateLimitState.requests.push(now);
    reviewerRateLimitState.lastSentAt = now;
  }

  /**
   * Reset rate limits (for testing and isolation)
   */
  resetRateLimits() {
    reviewerRateLimitState.requests = [];
    reviewerRateLimitState.lastSentAt = null;
  }

  /**
   * Handle server-side Send OTP for the Google Play Reviewer.
   * Completely bypasses Fast2SMS WhatsApp API.
   * Stores salted bcrypt hash of GOOGLE_PLAY_REVIEWER_OTP in MongoDB Otp collection.
   */
  async handleReviewerSendOtp(res, mobile) {
    const secretOtp = this.getReviewerOtp();
    if (!secretOtp) {
      console.error('[REVIEWER ERROR] GOOGLE_PLAY_REVIEWER_OTP is not configured in server environment.');
      return res.status(500).json({
        success: false,
        message: 'Reviewer authentication is not fully configured on server.',
      });
    }

    // Check rate limit
    this.checkReviewerRateLimit();

    // Ensure account exists
    await this.ensureReviewerAccount();

    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(secretOtp, salt);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes expiry

    // Replace existing login OTP for reviewer
    await Otp.deleteMany({ mobile, purpose: 'login' });
    await Otp.create({
      mobile,
      purpose: 'login',
      otpHash,
      expiresAt,
      attempts: 0,
      resendCount: 0,
      lastSentAt: new Date(),
    });

    // Non-sensitive audit log
    console.log(`[AUDIT] Google Play Reviewer requested login OTP for mobile: ******${mobile.slice(-4)} at ${new Date().toISOString()}`);

    return res.status(200).json({
      success: true,
      message: 'OTP sent successfully.',
    });
  }

  /**
   * Handle server-side Verify OTP for the Google Play Reviewer.
   */
  async handleReviewerVerifyOtp(req, res, mobile, enteredOtp) {
    const secretOtp = this.getReviewerOtp();
    if (!secretOtp) {
      return res.status(500).json({
        success: false,
        message: 'Reviewer authentication is not fully configured on server.',
      });
    }

    if (!enteredOtp || enteredOtp.length !== 6) {
      return res.status(400).json({
        success: false,
        message: 'Please enter a valid 6-digit OTP.',
      });
    }

    const otpRecord = await Otp.findOne({ mobile, purpose: 'login' });
    if (!otpRecord) {
      return res.status(400).json({
        success: false,
        message: 'OTP has expired or is invalid. Please request a new OTP.',
      });
    }

    if (otpRecord.expiresAt < new Date()) {
      await Otp.deleteOne({ _id: otpRecord._id });
      return res.status(400).json({
        success: false,
        message: 'OTP has expired. Please request a new OTP.',
      });
    }

    if (otpRecord.attempts >= REVIEWER_MAX_VERIFY_ATTEMPTS) {
      await Otp.deleteOne({ _id: otpRecord._id });
      return res.status(400).json({
        success: false,
        message: 'Maximum verification attempts exceeded. Please request a new OTP.',
      });
    }

    const isMatch = await bcrypt.compare(enteredOtp, otpRecord.otpHash);
    if (!isMatch) {
      otpRecord.attempts += 1;
      await otpRecord.save();
      const attemptsLeft = REVIEWER_MAX_VERIFY_ATTEMPTS - otpRecord.attempts;
      return res.status(400).json({
        success: false,
        message: `Invalid OTP. ${attemptsLeft} attempt(s) remaining.`,
      });
    }

    // Verification successful -> Delete OTP record
    await Otp.deleteOne({ _id: otpRecord._id });

    // Fetch reviewer user
    const user = await this.ensureReviewerAccount();
    user.lastLogin = new Date();
    await user.save();

    console.log(`[AUDIT] Google Play Reviewer authenticated successfully (User ID: ${user._id}) at ${new Date().toISOString()}`);

    // Build standard JWT & response
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '30d' });
    const [bank, wallet, kyc] = await Promise.all([
      Bank.findOne({ userId: user._id }),
      Wallet.findOne({ userId: user._id }),
      Kyc.findOne({ userId: user._id }),
    ]);

    const profile = user.toSafeJSON();
    profile.bank = bank ? bank.toSafeJSON() : null;
    profile.wallet = wallet ? { balancePaise: wallet.balancePaise, currency: wallet.currency } : null;
    profile.kyc = kyc ? kyc.toSafeJSON() : null;

    return res.status(200).json({
      success: true,
      data: {
        isNewUser: false,
        accessToken: token,
        token: token,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        user: profile,
      },
    });
  }

  /**
   * Handle server-side Send OTP for Security PIN / Wallet MPIN Forgot flow.
   * Completely bypasses Fast2SMS WhatsApp API.
   */
  async handleReviewerForgotOtp(res, mobile, purpose) {
    const secretOtp = this.getReviewerOtp();
    if (!secretOtp) {
      return res.status(500).json({
        success: false,
        message: 'Reviewer authentication is not fully configured on server.',
      });
    }

    this.checkReviewerRateLimit();

    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(secretOtp, salt);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await Otp.deleteMany({ mobile, purpose });
    await Otp.create({
      mobile,
      purpose,
      otpHash,
      expiresAt,
      attempts: 0,
      resendCount: 0,
      lastSentAt: new Date(),
    });

    console.log(`[AUDIT] Google Play Reviewer requested PIN reset OTP (purpose: ${purpose}) at ${new Date().toISOString()}`);

    return res.status(200).json({
      success: true,
      message: 'OTP sent successfully for PIN reset.',
      data: { phone: mobile },
    });
  }

  /**
   * Execute Isolated Sandbox Recharge Simulation.
   * - ZERO calls to A1Topup live provider.
   * - ZERO calls to live Razorpay.
   * - ZERO calls to live background workers (created directly in terminal 'SUCCESS').
   * - Debits ONLY the reviewer's personal test wallet.
   * - Writes WalletLedger and Transaction strictly for reviewer's userId.
   */
  async simulateRechargePayment({
    user,
    orderId,
    mobileNumber,
    amount,
    operatorCode,
    circleCode = '4',
    serviceType = 'mobile',
    internalOperatorName = 'Reviewer Sandbox Operator',
  }) {
    const amountNum = Number(amount);
    const amountPaise = Math.round(amountNum * 100);

    const wallet = await Wallet.findOne({ userId: user._id });
    if (!wallet) {
      throw new Error('Reviewer test wallet not found');
    }

    if (wallet.balancePaise < amountPaise) {
      throw new Error('Insufficient test wallet balance');
    }

    const previousBalancePaise = wallet.balancePaise;
    wallet.balancePaise -= amountPaise;
    await wallet.save();

    const testTxnId = `TEST_TXN_${Date.now()}`;
    const testOpRef = `TEST_REF_${Date.now()}`;

    // 1. Create RechargeTransaction directly in terminal SUCCESS state (workers skip terminal states)
    const rechargeTxn = await RechargeTransaction.create({
      orderId,
      userId: user._id,
      providerName: 'TEST_REVIEWER_SANDBOX',
      providerTransactionId: testTxnId,
      operatorReference: testOpRef,
      mobileNumber: String(mobileNumber),
      grossAmountPaise: amountPaise,
      commissionAmountPaise: 0,
      netPayablePaise: amountPaise,
      amount: amountNum,
      commissionAmount: 0,
      payableAmount: amountNum,
      operatorCode: String(operatorCode || 'TEST'),
      circleCode: String(circleCode || '4'),
      status: 'SUCCESS',
      walletSettlementStatus: 'SETTLED',
      walletSettlementAt: new Date(),
      paymentMethod: 'WALLET',
      serviceType: serviceType.toLowerCase(),
      providerStatus: 'SUCCESS',
      internalOperatorName,
      completedAt: new Date(),
      walletFinalizationStatus: 'COMPLETED',
      reservationStatus: 'CONSUMED',
    });

    // 2. Create WalletLedger entry strictly for reviewer's userId
    const ledgerEntry = await WalletLedger.create({
      userId: user._id,
      transactionType: 'DEBIT',
      amountPaise,
      previousBalancePaise,
      balanceAfterPaise: wallet.balancePaise,
      amount: amountNum,
      previousBalance: Number((previousBalancePaise / 100).toFixed(2)),
      balanceAfter: Number((wallet.balancePaise / 100).toFixed(2)),
      referenceType: 'RECHARGE',
      referenceId: rechargeTxn._id,
      description: `Test ${serviceType} Recharge for ${mobileNumber} - Order ID: ${orderId}`,
      remark: 'REVIEWER_TEST_TRANSACTION',
    });

    rechargeTxn.walletDebitLedgerId = ledgerEntry._id;
    await rechargeTxn.save();

    // 3. Create Transaction entry strictly for reviewer's userId
    await Transaction.create({
      userId: user._id,
      type: 'debit',
      amountPaise,
      payableAmountPaise: amountPaise,
      status: 'success',
      service: serviceType.toLowerCase(),
      referenceId: orderId,
      description: `Test ${serviceType} for ${mobileNumber}`,
      mobileNumber: String(mobileNumber),
      operatorName: internalOperatorName,
      paymentMethod: 'wallet',
      providerTransactionId: testTxnId,
      completedAt: new Date(),
    });

    console.log(`[AUDIT] Google Play Reviewer executed test simulated ${serviceType} recharge (Order: ${orderId}, Amount: ₹${amountNum}) at ${new Date().toISOString()}`);

    return {
      success: true,
      status: 'SUCCESS',
      orderId,
      transactionId: orderId,
      providerTransactionId: testTxnId,
      operatorReference: testOpRef,
      message: 'Recharge completed successfully (Test Sandbox Mode)',
      grossAmountPaise: amountPaise,
      netPayablePaise: amountPaise,
      amountPaise,
      subscriberNumber: String(mobileNumber),
      operatorName: internalOperatorName,
    };
  }
}

module.exports = new ReviewerService();
