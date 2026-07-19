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
    enum: ['success', 'pending', 'failed', 'reversed'],
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
  apiReference: {
    type: String,
  },
  paymentMethod: {
    type: String,
    default: 'wallet',
  }
}, {
  timestamps: true,
});

const Transaction = mongoose.model('Transaction', transactionSchema);
module.exports = Transaction;
