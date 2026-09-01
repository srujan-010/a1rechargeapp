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
    get: v => Math.round(v || 0),
    set: v => Math.round(v || 0),
  },
  payableAmountPaise: {
    type: Number,
    default: null,
    get: v => (v != null ? Math.round(v) : null),
    set: v => (v != null ? Math.round(v) : null),
  },
  commissionEarnedPaise: {
    type: Number,
    default: 0,
    get: v => Math.round(v || 0),
    set: v => Math.round(v || 0),
  },
  closingBalancePaise: {
    type: Number,
    default: null,
    get: v => (v != null ? Math.round(v) : null),
    set: v => (v != null ? Math.round(v) : null),
  },
  status: {
    type: String,
    enum: ['initiated', 'success', 'pending', 'processing', 'failed', 'reversed'],
    required: true,
  },
  service: {
    type: String,
    required: true,
  },
  referenceId: {
    type: String,
    required: true,
    unique: true,
  },
  description: {
    type: String,
  },
  recipientName: String,
  mobileNumber: String,
  accountType: {
    type: String,
    enum: ['PERSONAL', 'BUSINESS'],
    default: 'BUSINESS',
  },
  commissionRecordId: {
    type: String,
    default: null,
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
