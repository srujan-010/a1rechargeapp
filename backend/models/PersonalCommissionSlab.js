const mongoose = require('mongoose');

const personalCommissionSlabSchema = new mongoose.Schema(
  {
    operatorCode: {
      type: String,
      required: true,
      unique: true,
    },
    operatorName: {
      type: String,
      required: true,
    },
    serviceType: {
      type: String,
      enum: ['mobile', 'dth', 'bbps', 'electricity', 'gas', 'fastag'],
      default: 'mobile',
    },
    commissionType: {
      type: String,
      enum: ['percentage', 'flat'],
      default: 'percentage',
    },
    commissionValue: {
      type: Number,
      required: true,
      default: 0.8, // e.g., 0.8 means 0.80% benefit for Personal user
    },
    minAmount: {
      type: Number,
      default: 10,
    },
    maxAmount: {
      type: Number,
      default: 50000,
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'INACTIVE'],
      default: 'ACTIVE',
    },
  },
  { timestamps: true }
);

const PersonalCommissionSlab = mongoose.model('PersonalCommissionSlab', personalCommissionSlabSchema);
module.exports = PersonalCommissionSlab;
