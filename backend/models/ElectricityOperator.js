const mongoose = require('mongoose');

const requiredFieldSchema = new mongoose.Schema({
  key: { type: String, required: true },
  label: { type: String },
  placeholder: { type: String, default: '' },
  required: { type: Boolean, default: true },
  type: { type: String, default: 'text' }
}, { _id: false });

const electricityOperatorSchema = new mongoose.Schema({
  name: { type: String, required: true, index: true },
  shortName: { type: String },
  state: {
    type: String,
    required: true
  },
  stateCode: {
    type: String,
    required: false
  },
  operatorCode: { type: Number, required: true, unique: true }, // Keeping for backwards compat / UI mapping
  planApi: {
    operatorCode: { type: Number }
  },
  a1Topup: {
    operatorCode: { type: String }
  },
  serviceType: { type: String, default: 'electricity', index: true },
  category: { type: String, default: 'Electricity' },
  logo: { type: String },
  isPopular: { type: Boolean, default: false, index: true },
  isActive: { type: Boolean, default: true, index: true },
  sortOrder: { type: Number, default: 0 },
  requiresDistrictCode: { type: Boolean, default: false },
  requiresMobile: { type: Boolean, default: false },
  requiresDOB: { type: Boolean, default: false },
  searchKeywords: [{ type: String }],
  requiredFields: [requiredFieldSchema],
}, {
  timestamps: true
});

// Text index for search
electricityOperatorSchema.index({ name: 'text', searchKeywords: 'text' });

module.exports = mongoose.model('ElectricityOperator', electricityOperatorSchema, 'electricity_operators');
