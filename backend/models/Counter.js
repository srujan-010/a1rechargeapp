const mongoose = require('mongoose');

// Atomic, monotonic sequence counter used to generate human-readable
// Retailer IDs (RET000001, RET000002, ...). Stored in its own collection
// so increments are safe under concurrent registrations.
const counterSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    unique: true,
  },
  seq: {
    type: Number,
    default: 0,
  },
});

const Counter = mongoose.model('Counter', counterSchema);

module.exports = Counter;
