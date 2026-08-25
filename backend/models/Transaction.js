const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  type: {
    type: String,
    enum: ['credit', 'debit'],
    required: true,
  },
  amountPaise: {
    type: Number,
    required: true,
  },
  status: {
    type: String,
    enum: ['initiated', 'success', 'pending', 'failed', 'reversed'],
    required: true,
  },
  service: {
    type: String,
    required: true,
    // e.g., 'mobile_recharge', 'bbps', 'dmt', 'wallet_topup', etc.
  },
  referenceId: {
    type: String,
    required: true,
    unique: true,
  },
  description: {
    type: String,
  },
  closingBalancePaise: {
    type: Number,
  },
  recipientName: String,
  mobileNumber: String,
  commissionEarnedPaise: {
    type: Number,
    default: 0
  },
  operatorName: {
    type: String,
  },
  operatorId: {
    type: String,
    default: null,
  },
  apiReference: {
    type: String,
  },
  providerTransactionId: {
    type: String,
    default: null,
  },
  failureReason: {
    type: String,
    default: null,
  },
  providerMessage: {
    type: String,
    default: null,
  },
  paymentMethod: {
    type: String,
    default: 'wallet',
  },
  payableAmountPaise: {
    type: Number,
    default: null,
  },
  razorpayOrderId: {
    type: String,
    default: null,
  },
  razorpayPaymentId: {
    type: String,
    default: null,
  },
  completedAt: {
    type: Date,
    default: null,
  }
}, {
  timestamps: true,
});

transactionSchema.index({ userId: 1, createdAt: -1 });
transactionSchema.index({ userId: 1, service: 1, status: 1 });

const Transaction = mongoose.model('Transaction', transactionSchema);
module.exports = Transaction;

