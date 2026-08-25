const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    retailerId: {
      type: String,
      required: true,
      unique: true,
    },
    name: {
      type: String,
      required: true,
    },
    role: {
      type: String,
      enum: ['retailer', 'admin'],
      default: 'retailer',
    },
    phone: {
      type: String,
      required: true,
      unique: true,
    },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      default: null,
    },
    dob: {
      type: Date,
      default: null,
    },
    gender: {
      type: String,
      enum: ['Male', 'Female', 'Other', null],
      default: null,
    },
    avatarUrl: {
      type: String,
      default: null,
    },
    // Shop / business details
    shopName: {
      type: String,
      trim: true,
      default: null,
    },
    shopAddress: {
      type: String,
      trim: true,
      default: null,
    },
    city: {
      type: String,
      trim: true,
      default: null,
    },
    state: {
      type: String,
      trim: true,
      default: null,
    },
    pincode: {
      type: String,
      trim: true,
      default: null,
    },
    aadhaarNumber: {
      type: String,
      trim: true,
      default: null,
    },
    panNumber: {
      type: String,
      trim: true,
      uppercase: true,
      default: null,
    },
    gstNumber: {
      type: String,
      trim: true,
      uppercase: true,
      default: null,
    },
    // Legacy MPIN fields (kept for migration fallback)
    mpinHash: {
      type: String,
      required: false,
    },
    mpinCreatedAt: {
      type: Date,
    },
    mpinUpdatedAt: {
      type: Date,
    },
    failedMpinAttempts: {
      type: Number,
      default: 0,
    },
    lastMpinAttempt: {
      type: Date,
    },
    lockUntil: {
      type: Date,
    },

    // --- SECURITY PIN (APP ACCESS / ACCOUNT SECURITY ONLY) ---
    securityPinHash: {
      type: String,
      required: false,
    },
    securityPinCreatedAt: {
      type: Date,
    },
    securityPinUpdatedAt: {
      type: Date,
    },
    failedSecurityPinAttempts: {
      type: Number,
      default: 0,
    },
    lastSecurityPinAttempt: {
      type: Date,
    },
    securityPinLockUntil: {
      type: Date,
    },

    // --- WALLET MPIN (PAYMENT AUTHORIZATION ONLY) ---
    walletMpinHash: {
      type: String,
      required: false,
    },
    walletMpinCreatedAt: {
      type: Date,
    },
    walletMpinUpdatedAt: {
      type: Date,
    },
    failedWalletMpinAttempts: {
      type: Number,
      default: 0,
    },
    lastWalletMpinAttempt: {
      type: Date,
    },
    walletMpinLockUntil: {
      type: Date,
    },

    kycStatus: {
      type: String,
      enum: ['notStarted', 'pending', 'verified', 'rejected'],
      default: 'notStarted',
    },
    firebaseUid: {
      type: String,
      unique: true,
      sparse: true,
    },
    fcmToken: {
      type: String,
      default: null,
    },
    isOnboarded: {
      type: Boolean,
      default: false,
    },
    isVerified: {
      type: Boolean,
      default: false,
    },
    lastLogin: {
      type: Date,
    },
    accountType: {
      type: String,
      enum: ['PERSONAL', 'BUSINESS', 'RETAILER'],
      default: 'BUSINESS',
    },
    hasPhysicalShop: {
      type: Boolean,
      default: true,
    },
    businessType: {
      type: String,
      default: null,
    },
    termsAccepted: {
      type: Boolean,
      default: false,
    },
    termsAcceptedAt: {
      type: Date,
      default: null,
    },
    welcomeWhatsAppSent: {
      type: Boolean,
      default: false,
    },
    welcomeWhatsAppSentAt: {
      type: Date,
      default: null,
    },
    welcomeWhatsAppMessageId: {
      type: String,
      default: null,
    },
    welcomeWhatsAppStatus: {
      type: String,
      default: null,
    },
    recentContacts: [
      {
        phone: { type: String, required: true },
        operatorId: { type: String, required: true },
        circle: { type: String, required: true },
        contactName: { type: String, default: null },
        lastRechargeDate: { type: Date, required: true },
        lastRechargeAmountPaise: { type: Number, required: true },
        rechargeCount: { type: Number, default: 1 },
      }
    ],
  },
  { timestamps: true }
);

// Method to verify Security PIN (App Access)
userSchema.methods.matchSecurityPin = async function (enteredPin) {
  if (this.securityPinLockUntil && this.securityPinLockUntil > Date.now()) {
    throw new Error('Account security locked due to too many failed attempts. Try again later.');
  }

  if (!this.securityPinHash) {
    throw new Error('Security PIN not configured for this user');
  }

  const isMatch = await bcrypt.compare(enteredPin, this.securityPinHash);

  if (isMatch) {
    if (this.failedSecurityPinAttempts || this.securityPinLockUntil) {
      this.failedSecurityPinAttempts = 0;
      this.securityPinLockUntil = undefined;
      if (this.db && this.db.readyState === 1) await this.save();
    }
    return true;
  } else {
    this.failedSecurityPinAttempts = (this.failedSecurityPinAttempts || 0) + 1;
    this.lastSecurityPinAttempt = Date.now();
    if (this.failedSecurityPinAttempts >= 5) {
      this.securityPinLockUntil = Date.now() + 15 * 60 * 1000;
    }
    if (this.db && this.db.readyState === 1) await this.save();
    return false;
  }
};

// Method to verify Wallet MPIN (Payment Authorization)
userSchema.methods.matchWalletMpin = async function (enteredMpin) {
  const activeLock = this.walletMpinLockUntil || this.lockUntil;
  if (activeLock && activeLock > Date.now()) {
    throw new Error('Wallet payment locked due to too many failed MPIN attempts. Try again later.');
  }

  const targetHash = this.walletMpinHash || this.mpinHash;
  if (!targetHash) {
    throw new Error('Wallet MPIN not configured for this user');
  }

  const isMatch = await bcrypt.compare(enteredMpin, targetHash);

  if (isMatch) {
    if (this.failedWalletMpinAttempts || this.failedMpinAttempts || this.walletMpinLockUntil || this.lockUntil) {
      this.failedWalletMpinAttempts = 0;
      this.failedMpinAttempts = 0;
      this.walletMpinLockUntil = undefined;
      this.lockUntil = undefined;
      if (this.db && this.db.readyState === 1) await this.save();
    }
    return true;
  } else {
    this.failedWalletMpinAttempts = (this.failedWalletMpinAttempts || 0) + 1;
    this.failedMpinAttempts = (this.failedMpinAttempts || 0) + 1;
    this.lastWalletMpinAttempt = Date.now();
    this.lastMpinAttempt = Date.now();
    if (this.failedWalletMpinAttempts >= 5 || this.failedMpinAttempts >= 5) {
      const lockTime = Date.now() + 15 * 60 * 1000;
      this.walletMpinLockUntil = lockTime;
      this.lockUntil = lockTime;
    }
    if (this.db && this.db.readyState === 1) await this.save();
    return false;
  }
};

// Legacy alias to matchWalletMpin
userSchema.methods.matchMpin = function (enteredMpin) {
  return this.matchWalletMpin(enteredMpin);
};

// Safe client-facing representation (no hashes, masked PII).
userSchema.methods.toSafeJSON = function toSafeJSON() {
  const mask = (v) => {
    if (!v) return null;
    return v.length > 4 ? `XXXX${v.slice(-4)}` : v;
  };
  return {
    id: this._id,
    retailerId: this.retailerId,
    name: this.name,
    role: this.role || 'retailer',
    phone: this.phone,
    email: this.email,
    dob: this.dob,
    gender: this.gender,
    avatarUrl: this.avatarUrl,
    shopName: this.shopName,
    shopAddress: this.shopAddress,
    city: this.city,
    state: this.state,
    pincode: this.pincode,
    aadhaarNumber: mask(this.aadhaarNumber),
    panNumber: mask(this.panNumber),
    gstNumber: this.gstNumber ? mask(this.gstNumber) : null,
    kycStatus: this.kycStatus,
    isOnboarded: this.isOnboarded,
    accountType: this.accountType || 'RETAILER',
    hasPhysicalShop: this.hasPhysicalShop !== false,
    businessType: this.businessType || null,
    isVerified: this.isVerified,
    hasSecurityPin: !!this.securityPinHash,
    securityPinConfigured: !!this.securityPinHash,
    hasWalletMpin: !!(this.walletMpinHash || this.mpinHash),
    walletMpinConfigured: !!(this.walletMpinHash || this.mpinHash),
    hasMpin: !!(this.walletMpinHash || this.mpinHash),
    recentContacts: this.recentContacts || [],
    fcmToken: this.fcmToken,
    createdAt: this.createdAt,
  };
};

const User = mongoose.model('User', userSchema);
module.exports = User;
