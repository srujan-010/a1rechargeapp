const mongoose = require('mongoose');

const walletFundingTransactionSchema = new mongoose.Schema(
  {
    internalTransactionId: {
      type: String,
      required: true,
      unique: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    amountPaise: {
      type: Number,
      required: true,
    },
    amountRupees: {
      type: Number,
      required: true,
    },
    currency: {
      type: String,
      default: 'INR',
    },
    razorpayOrderId: {
      type: String,
      sparse: true,
    },
    razorpayPaymentId: {
      type: String,
      default: null,
    },
    razorpaySignature: {
      type: String,
      default: null,
    },
    status: {
      type: String,
      enum: ['CREATED', 'PENDING', 'SUCCESS', 'FAILED', 'CANCELLED', 'EXPIRED', 'REFUNDED', 'VERIFYING_PENDING'],
      default: 'CREATED',
    },
    fundingMethod: {
      type: String,
      default: 'RAZORPAY',
    },
    failureCode: {
      type: String,
      default: null,
    },
    failureDescription: {
      type: String,
      default: null,
    },
    failureSource: {
      type: String,
      default: null,
    },
    failureStep: {
      type: String,
      default: null,
    },
    failureReason: {
      type: String,
      default: null,
    },
  },
  { timestamps: true }
);

walletFundingTransactionSchema.index({ userId: 1, createdAt: -1 });
walletFundingTransactionSchema.index({ razorpayOrderId: 1 });
walletFundingTransactionSchema.index({ razorpayPaymentId: 1 });

const WalletFundingTransaction = mongoose.model('WalletFundingTransaction', walletFundingTransactionSchema);
module.exports = WalletFundingTransaction;
