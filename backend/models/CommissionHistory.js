const mongoose = require('mongoose');

const commissionHistorySchema = new mongoose.Schema(
  {
    transactionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'RechargeTransaction',
      required: true,
      unique: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    operatorCode: {
      type: String,
      required: true,
    },
    rechargeAmountPaise: {
      type: Number,
      default: 0,
      get: v => Math.round(v || 0),
      set: v => Math.round(v || 0),
    },
    providerCommissionAmountPaise: {
      type: Number,
      default: 0,
      get: v => Math.round(v || 0),
      set: v => Math.round(v || 0),
    },
    retailerCommissionAmountPaise: {
      type: Number,
      default: 0,
      get: v => Math.round(v || 0),
      set: v => Math.round(v || 0),
    },
    companyProfitAmountPaise: {
      type: Number,
      default: 0,
      get: v => Math.round(v || 0),
      set: v => Math.round(v || 0),
    },
    rechargeAmount: {
      type: Number,
      required: true,
    },
    providerCommissionPercentage: {
      type: Number,
      required: true,
    },
    providerCommissionAmount: {
      type: Number,
      required: true,
    },
    retailerCommissionPercentage: {
      type: Number,
      required: true,
    },
    retailerCommissionAmount: {
      type: Number,
      required: true,
    },
    companyProfitPercentage: {
      type: Number,
      required: true,
    },
    companyProfitAmount: {
      type: Number,
      required: true,
    },
  },
  { timestamps: true }
);

const CommissionHistory = mongoose.model('CommissionHistory', commissionHistorySchema);
module.exports = CommissionHistory;
