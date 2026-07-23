const mongoose = require('mongoose');

const requiredFieldSchema = new mongoose.Schema({
  key: { type: String, required: true },
  label: { type: String },
  placeholder: { type: String, default: '' },
  required: { type: Boolean, default: true },
  type: { type: String, default: 'text' }
}, { _id: false });

const gasOperatorSchema = new mongoose.Schema({
  name: { type: String, required: true, index: true },
  shortName: { type: String },
  state: {
    type: String,
    required: false
  },
  stateCode: {
    type: String,
    required: false
  },
  planApi: {
    operatorCode: { type: Number, required: true }
  },
  a1Topup: {
    operatorCode: { type: String, required: true }
  },
  service: { type: String, default: 'Gas', index: true },
  serviceType: { type: String, default: 'gas' },
  category: { type: String, default: 'Gas' },
  logo: { type: String },
  isPopular: { type: Boolean, default: false, index: true },
  isActive: { type: Boolean, default: true, index: true },
  sortOrder: { type: Number, default: 0 },
  searchKeywords: [{ type: String }],
  requiredFields: [requiredFieldSchema],
}, {
  timestamps: true
});

// Text index for search
gasOperatorSchema.index({ name: 'text', searchKeywords: 'text' });

module.exports = mongoose.model('GasOperator', gasOperatorSchema, 'gas_operators');
