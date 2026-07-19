const Counter = require('../models/Counter');

// Generates the next sequential Retailer ID in the format RET######
// (zero-padded 6-digit sequence). Uses findOneAndUpdate with upsert so the
// increment is atomic and safe under concurrent registrations.
const generateRetailerId = async () => {
  const counter = await Counter.findOneAndUpdate(
    { name: 'retailerId' },
    { $inc: { seq: 1 } },
    { new: true, upsert: true },
  );

  return `RET${counter.seq.toString().padStart(6, '0')}`;
};

module.exports = generateRetailerId;
