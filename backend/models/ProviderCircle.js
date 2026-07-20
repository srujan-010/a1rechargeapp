const mongoose = require('mongoose');

const providerCircleSchema = new mongoose.Schema(
  {
    provider: {
      type: String,
      required: true,
      default: 'A1Topup',
      index: true,
    },
    state: {
      type: String,
      required: true,
    },
    code: {
      type: String,
      required: true,
      index: true,
    },
    status: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

// Ensure a provider does not have duplicate circle codes
providerCircleSchema.index({ provider: 1, code: 1 }, { unique: true });

const ProviderCircle = mongoose.model('ProviderCircle', providerCircleSchema);
module.exports = ProviderCircle;
