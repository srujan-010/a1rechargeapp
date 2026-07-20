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
