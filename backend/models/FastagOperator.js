const mongoose = require('mongoose');

const requiredFieldSchema = new mongoose.Schema({
  key: { type: String, required: true },
  label: { type: String },
  placeholder: { type: String, default: '' },
  required: { type: Boolean, default: true },
  type: { type: String, default: 'text' }
}, { _id: false });

const fastagOperatorSchema = new mongoose.Schema({
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
  operatorCode: { type: Number, required: true, unique: true },
  planApi: {
    operatorCode: { type: Number }
  },
  a1Topup: {
    operatorCode: { type: String }
  },
  serviceType: { type: String, default: 'fastag', index: true },
  category: { type: String, default: 'FASTag' },
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
fastagOperatorSchema.index({ name: 'text', searchKeywords: 'text' });

module.exports = mongoose.model('FastagOperator', fastagOperatorSchema, 'fastag_operators');
