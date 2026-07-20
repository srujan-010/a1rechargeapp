const mongoose = require('mongoose');

const planItemSchema = new mongoose.Schema({
  id: { type: String, required: false },
  amount: { type: Number, required: true },
  name: { type: String, required: false },
  category: { type: String, required: false },
  validity: { type: String, required: false },
  benefit: { type: String, required: false },
  calls: { type: String, required: false },
  data: { type: String, required: false },
  sms: { type: String, required: false },
  subscriptions: { type: [String], default: [] }
}, { _id: false });

const planCacheSchema = new mongoose.Schema(
  {
    provider: {
      type: String,
      required: true,
      default: 'PlansInfo',
    },
    service: {
      type: String,
      required: true, // mobile, dth
      enum: ['mobile', 'dth']
    },
    type: {
      type: String,
      required: true, // prepaid, postpaid, packs, pack_details, alacarte
      enum: ['prepaid', 'postpaid', 'packs', 'pack_details', 'alacarte']
    },
    operatorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'ProviderOperator',
      required: false, // For things that don't need operator (if any) or are purely generic
      index: true,
    },
    circleId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'ProviderCircle',
      required: false, // DTH packs usually don't need circle
      index: true,
    },
    packId: {
      type: String,
      required: false, // For DTH pack details
      index: true,
    },
    plans: [planItemSchema],
    lastSynced: {
      type: Date,
      default: Date.now,
    },
    expiresAt: {
      type: Date,
      required: true,
    },
  },
  { timestamps: true }
);

// Compound index for fast lookup
planCacheSchema.index({ provider: 1, service: 1, type: 1, operatorId: 1, circleId: 1, packId: 1 }, { unique: true });

// TTL index to automatically delete expired documents
planCacheSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const PlanCache = mongoose.model('PlanCache', planCacheSchema);
module.exports = PlanCache;
