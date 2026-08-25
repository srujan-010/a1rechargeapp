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
    default: 'BOTH'
  },
  notificationType: {
    type: String,
    required: true,
    enum: [
      'RECHARGE_PROCESSING',
      'RECHARGE_PENDING',
      'RECHARGE_SUCCESS',
      'RECHARGE_FAILED',
      'WALLET_TOPUP_SUCCESS',
      'WALLET_TOPUP_FAILED',
      'WALLET_TOPUP_PENDING',
      'ADMIN_WALLET_CREDIT',
      'WALLET_DEBIT',
      'COMMISSION_EARNED',
      'MPIN_SET_SUCCESS',
      'MPIN_RESET_SUCCESS',
      'MPIN_UPDATE_FAILED',
      'SECURITY_PIN_SET_SUCCESS',
      'SECURITY_PIN_CHANGED_SUCCESS',
      'SECURITY_PIN_RESET_SUCCESS',
      'SECURITY_PIN_UPDATE_FAILED',
      'WALLET_MPIN_SET_SUCCESS',
      'WALLET_MPIN_CHANGED_SUCCESS',
      'WALLET_MPIN_RESET_SUCCESS',
      'WALLET_MPIN_UPDATE_FAILED',
      'ONBOARDING_SUCCESS',
      'ONBOARDING_FAILED',
      'SECURITY_NEW_LOGIN',
      'PROFILE_UPDATED',
      'SYSTEM',
      'ADMIN_ANNOUNCEMENT'
    ],
    default: 'SYSTEM'
  },
  title: {
    type: String,
    required: true
  },
  message: {
    type: String,
    required: true
  },
  body: {
    type: String
  },
  category: {
    type: String,
    enum: ['RECHARGE', 'WALLET', 'COMMISSION', 'MPIN', 'SECURITY', 'SECURITY_PIN', 'WALLET_MPIN', 'ONBOARDING', 'ACCOUNT', 'SYSTEM', 'SUCCESS', 'INFO', 'WARNING', 'ERROR'],
    default: 'RECHARGE'
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
  actionRoute: {
    type: String,
    default: null
  },
  action: {
    type: String,
    default: null
  },
  actionData: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  data: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  relatedOrderId: {
    type: String,
    default: null
  },
  relatedTransactionId: {
    type: String,
    default: null
  }
}, {
  timestamps: true
});

notificationSchema.index({ userId: 1, createdAt: -1 });
notificationSchema.index({ userId: 1, isRead: 1 });
notificationSchema.index({ userId: 1, relatedOrderId: 1, notificationType: 1 }, { sparse: true });
notificationSchema.index({ userId: 1, relatedTransactionId: 1, notificationType: 1 }, { sparse: true });

module.exports = mongoose.model('Notification', notificationSchema);
