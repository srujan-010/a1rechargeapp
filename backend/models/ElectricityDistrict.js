const mongoose = require('mongoose');

const electricityDistrictSchema = new mongoose.Schema({
  operatorCode: {
    type: Number,
    required: true,
    index: true
  },
  state: {
    type: String,
    required: true
  },
  districtName: {
    type: String,
    required: true
  },
  districtCode: {
    type: String,
    required: true
  }
}, {
  timestamps: true
});

const ElectricityDistrict = mongoose.model('ElectricityDistrict', electricityDistrictSchema);
module.exports = ElectricityDistrict;
