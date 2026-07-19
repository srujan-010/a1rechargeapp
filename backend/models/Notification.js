const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: false // null for system broadcast to all users
  },
  type: {
    type: String,
    enum: ['IN_APP', 'PUSH', 'BOTH'],
    default: 'IN_APP'
  },
  title: {
    type: String,
    required: true
  },
  message: {
    type: String,
    required: true
  },
  category: {
    type: String,
    enum: ['SUCCESS', 'INFO', 'WARNING', 'ERROR', 'OFFER', 'SYSTEM'],
    default: 'INFO'
  },
  priority: {
    type: String,
    enum: ['LOW', 'NORMAL', 'HIGH'],
    default: 'NORMAL'
  },
  isRead: {
    type: Boolean,
    default: false
  },
  action: {
    type: String, // e.g. "ROUTE_WALLET", "ROUTE_HISTORY", "ROUTE_KYC"
    default: null
  },
  actionData: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  }
}, {
  timestamps: true
});

notificationSchema.index({ userId: 1, createdAt: -1 });
notificationSchema.index({ isRead: 1 });

module.exports = mongoose.model('Notification', notificationSchema);
