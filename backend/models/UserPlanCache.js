const mongoose = require('mongoose');

const userPlanCacheSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    mobileNumber: { type: String, required: true, index: true },
    operatorCode: { type: String },
    operatorName: { type: String },
    circleCode: { type: String },
    planName: { type: String },
    validity: { type: String },
    expiryDate: { type: Date },
    daysRemaining: { type: Number },
    amount: { type: Number },
    statusText: { type: String },
    rawProviderResponse: { type: Object },
    fetchedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

userPlanCacheSchema.index({ userId: 1, mobileNumber: 1 }, { unique: true });

const UserPlanCache = mongoose.model('UserPlanCache', userPlanCacheSchema);
module.exports = UserPlanCache;
