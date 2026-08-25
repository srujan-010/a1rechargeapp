const mongoose = require('mongoose');

const operatorCommissionSchema = new mongoose.Schema(
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
      // e.g., 4 means 4%
    },
    retailerCommission: {
      type: Number,
      required: true,
      default: 0,
      // e.g., 2 means 2%
    },
    personalCommission: {
      type: Number,
      required: false,
      default: null,
      // e.g., 0.8 means 0.8% benefit for Personal customer (if null, system uses retailerCommission - PERSONAL_COMMISSION_ADJUSTMENT)
    },
    companyCommission: {
      type: Number,
      required: true,
      default: 0,
      // e.g., 2 means 2%
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'INACTIVE'],
      default: 'ACTIVE',
    },
  },
  { timestamps: true }
);

const OperatorCommission = mongoose.model('OperatorCommission', operatorCommissionSchema);
module.exports = OperatorCommission;
