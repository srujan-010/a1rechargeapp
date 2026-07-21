const mongoose = require('mongoose');

const providerOperatorSchema = new mongoose.Schema(
  {
    provider: {
      type: String,
      required: true,
      default: 'A1Topup',
      index: true,
    },
    name: {
      type: String,
      required: true,
    },
    code: {
      type: String,
      required: true,
      index: true,
    },
    serviceType: {
      type: String,
      required: true,
      enum: ['Mobile', 'DTH', 'PostPaid', 'Electricity', 'Gas', 'Insurance', 'Money Transfer', 'Data Card', 'Fastag', 'Other'],
      index: true,
    },
    plansInfoCode: {
      type: String,
      required: false,
      index: true,
    },
    status: {
      type: Boolean,
      default: true,
    },
    displayOrder: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true }
);

// Ensure a provider does not have duplicate operator codes
providerOperatorSchema.index({ provider: 1, code: 1 }, { unique: true });

const ProviderOperator = mongoose.model('ProviderOperator', providerOperatorSchema);
module.exports = ProviderOperator;
