const mongoose = require('mongoose');

const otpSchema = new mongoose.Schema(
  {
    mobile: {
      type: String,
      required: true,
      index: true,
    },
    purpose: {
      type: String,
      enum: ['login', 'security_pin_reset', 'wallet_pin_reset'],
      default: 'login',
      required: true,
      index: true,
    },
    otpHash: {
      type: String,
      required: true,
    },
    expiresAt: {
      type: Date,
      required: true,
    },
    attempts: {
      type: Number,
      default: 0,
    },
    resendCount: {
      type: Number,
      default: 0,
    },
    lastSentAt: {
      type: Date,
      default: Date.now,
    },
    createdAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

// Compound index for fast queries by mobile and purpose
otpSchema.index({ mobile: 1, purpose: 1 });

// TTL index to automatically delete expired OTP documents from MongoDB
otpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const Otp = mongoose.model('Otp', otpSchema);
module.exports = Otp;
