const mongoose = require('mongoose');

const operatorCommissionSchema = new mongoose.Schema(
  {
    accountType: {
      type: String,
      enum: ['PERSONAL', 'BUSINESS'],
      default: 'BUSINESS',
      required: true,
    },
    operatorCode: {
      type: String,
      required: true,
      trim: true,
      uppercase: true,
    },
    operatorName: {
      type: String,
      required: true,
      trim: true,
    },
    serviceType: {
      type: String,
      enum: ['mobile', 'dth', 'bbps', 'electricity', 'gas', 'fastag', 'aeps', 'dmt'],
      default: 'mobile',
    },
    commissionType: {
      type: String,
      enum: ['percentage', 'flat'],
      default: 'percentage',
    },
    providerCommission: {
      type: Number,
      required: true,
      default: 0,
    },
    retailerCommission: {
      type: Number,
      required: true,
      default: 0,
    },
    personalCommission: {
      type: Number,
      required: false,
      default: null,
    },
    companyCommission: {
      type: Number,
      required: true,
      default: 0,
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'INACTIVE'],
      default: 'ACTIVE',
    },
  },
  { timestamps: true }
);

// Compound Index for accountType + serviceType + operatorCode
operatorCommissionSchema.index({ accountType: 1, serviceType: 1, operatorCode: 1 }, { unique: true });

const OperatorCommission = mongoose.model('OperatorCommission', operatorCommissionSchema);
module.exports = OperatorCommission;
