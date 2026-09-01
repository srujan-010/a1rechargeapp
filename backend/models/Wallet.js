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
    get: v => Math.round(v || 0),
    set: v => Math.round(v || 0),
  },
  onHoldPaise: {
    type: Number,
    required: true,
    default: 0,
    get: v => Math.round(v || 0),
    set: v => Math.round(v || 0),
  },
  currency: {
    type: String,
    default: 'INR',
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true },
});

walletSchema.virtual('availableBalancePaise').get(function () {
  const balance = Math.round(this.balancePaise || 0);
  const hold = Math.round(this.onHoldPaise || 0);
  return Math.max(0, balance - hold);
});

const Wallet = mongoose.model('Wallet', walletSchema);
module.exports = Wallet;
