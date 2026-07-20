const mongoose = require('mongoose');

const providerWalletSchema = new mongoose.Schema(
  {
    providerName: {
      type: String,
      required: true,
      unique: true,
      default: 'A1Topup',
    },
    balance: {
      type: Number,
      required: true,
      default: 0,
    },
    currency: {
      type: String,
      default: 'INR',
    },
    lastCheckedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

const ProviderWallet = mongoose.model('ProviderWallet', providerWalletSchema);
module.exports = ProviderWallet;
