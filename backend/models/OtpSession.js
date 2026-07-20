const mongoose = require('mongoose');

const otpSessionSchema = new mongoose.Schema(
  {
    phone: {
      type: String,
      required: true,
      unique: true,
    },
    requestCount: {
      type: Number,
      default: 0,
    },
    lastRequestAt: {
      type: Date,
    },
    verifyAttempts: {
      type: Number,
      default: 0,
    },
    blockedUntil: {
      type: Date,
    },
  },
  { timestamps: true }
);

const OtpSession = mongoose.model('OtpSession', otpSessionSchema);
module.exports = OtpSession;
