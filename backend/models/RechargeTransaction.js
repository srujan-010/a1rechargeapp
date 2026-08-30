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
      enum: ['INITIATED', 'PAYMENT_PENDING', 'PAYMENT_SUCCESS', 'RECHARGE_PROCESSING', 'PROCESSING', 'PENDING', 'SUCCESS', 'FAILED', 'REFUNDED', 'REVERSED'],
      default: 'INITIATED',
    },
    refundStatus: {
      type: String,
      enum: ['NONE', 'NOT_APPLICABLE', 'PROCESSING', 'REFUNDED', 'FAILED'],
      default: 'NONE',
    },
    refundAmount: {
      type: Number,
      default: 0,
    },
    refundReason: {
      type: String,
      default: null,
    },
    refundReference: {
      type: String,
      default: null,
    },
    refundedAt: {
      type: Date,
      default: null,
    },
    refundError: {
      type: String,
      default: null,
    },
    paymentMethod: {
      type: String,
      default: 'WALLET',
    },
    razorpayOrderId: {
      type: String,
      default: null,
    },
    razorpayPaymentId: {
      type: String,
      default: null,
    },
    razorpaySignature: {
      type: String,
      default: null,
    },
    accountType: {
      type: String,
      enum: ['PERSONAL', 'BUSINESS', 'RETAILER'],
      default: 'BUSINESS',
    },
    commissionRecordId: {
      type: String,
      default: null,
    },
    commissionPercent: {
      type: Number,
      default: 0,
    },
    commissionAmount: {
      type: Number,
      default: 0,
    },
    payableAmount: {
      type: Number,
      default: 0,
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
    providerRequestSent: {
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
    walletFinalizationStatus: {
      type: String,
      enum: ['NONE', 'PENDING', 'COMPLETED', 'FAILED'],
      default: 'NONE',
    },
    reservationStatus: {
      type: String,
      enum: ['NONE', 'ACTIVE', 'CONSUMED', 'RELEASED'],
      default: 'NONE',
    },
  },
  { timestamps: true }
);

const RechargeTransaction = mongoose.model('RechargeTransaction', rechargeTransactionSchema);
module.exports = RechargeTransaction;
