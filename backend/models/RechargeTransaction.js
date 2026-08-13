const mongoose = require('mongoose');

const rechargeTransactionSchema = new mongoose.Schema(
  {
    orderId: {
      type: String,
      required: true,
      unique: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    providerName: {
      type: String,
      required: true,
      default: 'A1Topup',
    },
    providerTransactionId: {
      type: String,
      default: null,
    },
    operatorReference: {
      type: String,
      default: null,
    },
    mobileNumber: {
      type: String,
      required: true,
    },
    amount: {
      type: Number,
      required: true,
    },
    operatorCode: {
      type: String,
      required: true,
    },
    circleCode: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      enum: ['INITIATED', 'PENDING', 'SUCCESS', 'FAILED', 'REFUNDED'],
      default: 'INITIATED',
    },
    operatorId: {
      type: String,
      default: null,
    },
    providerMessage: {
      type: String,
      default: null,
    },
    clientOrderId: {
      type: String,
      default: null,
    },
    reservedAmount: {
      type: Number,
      default: 0,
    },
    commissionCalculated: {
      type: Boolean,
      default: false,
    },
    failureReason: {
      type: String,
      default: null,
    },
    providerStatus: {
      type: String,
      default: null,
    },
    serviceType: {
      type: String,
      default: 'mobile',
    },
    providerOperatorCode: {
      type: String,
      default: null,
    },
    planId: {
      type: String,
      default: null,
    },
    planName: {
      type: String,
      default: null,
    },
    planType: {
      type: String,
      default: null,
    },
    internalOperatorId: {
      type: String,
      default: null,
    },
    internalOperatorName: {
      type: String,
      default: null,
    },
    completedAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

const RechargeTransaction = mongoose.model('RechargeTransaction', rechargeTransactionSchema);
module.exports = RechargeTransaction;
