const mongoose = require('mongoose');

const walletLedgerSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    adminId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    transactionType: {
      type: String,
      enum: ['CREDIT', 'DEBIT'],
      required: true,
    },
    amount: {
      type: Number,
      required: true,
    },
    previousBalance: {
      type: Number,
      default: 0,
    },
    balanceAfter: {
      type: Number,
      required: true,
    },
    referenceType: {
      type: String,
      enum: ['RECHARGE', 'COMMISSION', 'REFUND', 'ADD_MONEY', 'MANUAL', 'ADMIN_CREDIT', 'RAZORPAY_WALLET_CREDIT'],
      required: true,
    },
    referenceId: {
      type: mongoose.Schema.Types.Mixed,
      required: true,
    },
    remark: {
      type: String,
      default: null,
    },
    description: {
      type: String,
      required: true,
    },
  },
  { timestamps: true }
);

const WalletLedger = mongoose.model('WalletLedger', walletLedgerSchema);
module.exports = WalletLedger;
