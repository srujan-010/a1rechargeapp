const mongoose = require('mongoose');

const walletSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
  },
  balancePaise: {
    type: Number,
    required: true,
    default: 0,
  },
  onHoldPaise: {
    type: Number,
    required: true,
    default: 0,
  },
  currency: {
    type: String,
    default: 'INR',
  }
}, {
  timestamps: true,
});

const Wallet = mongoose.model('Wallet', walletSchema);
module.exports = Wallet;
