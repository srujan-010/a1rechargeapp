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
    amountPaise: {
      type: Number,
      required: true,
      get: v => Math.round(v || 0),
      set: v => Math.round(v || 0),
    },
    previousBalancePaise: {
      type: Number,
      default: 0,
      get: v => Math.round(v || 0),
      set: v => Math.round(v || 0),
    },
    balanceAfterPaise: {
      type: Number,
      required: true,
      get: v => Math.round(v || 0),
      set: v => Math.round(v || 0),
    },
    // Backwards compatibility fields (rupees)
    amount: {
      type: Number,
    },
    previousBalance: {
      type: Number,
    },
    balanceAfter: {
      type: Number,
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

walletLedgerSchema.index({ userId: 1, referenceType: 1, referenceId: 1, transactionType: 1 }, { unique: true });
walletLedgerSchema.index({ userId: 1, createdAt: -1 });

const WalletLedger = mongoose.model('WalletLedger', walletLedgerSchema);
module.exports = WalletLedger;
