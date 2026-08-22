const mongoose = require('mongoose');

const adminAuditLogSchema = new mongoose.Schema(
  {
    adminId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    adminName: {
      type: String,
      required: true,
    },
    adminPhone: {
      type: String,
      required: true,
    },
    retailerUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    retailerId: {
      type: String,
      required: true,
    },
    retailerName: {
      type: String,
      required: true,
    },
    retailerPhone: {
      type: String,
      required: true,
    },
    amountRupees: {
      type: Number,
      required: true,
    },
    amountPaise: {
      type: Number,
      required: true,
    },
    previousBalanceRupees: {
      type: Number,
      required: true,
    },
    previousBalancePaise: {
      type: Number,
      required: true,
    },
    newBalanceRupees: {
      type: Number,
      required: true,
    },
    newBalancePaise: {
      type: Number,
      required: true,
    },
    remark: {
      type: String,
      default: '',
    },
    referenceId: {
      type: String,
      required: true,
      unique: true,
    },
  },
  { timestamps: true }
);

adminAuditLogSchema.index({ retailerUserId: 1, createdAt: -1 });
adminAuditLogSchema.index({ adminId: 1, createdAt: -1 });

const AdminAuditLog = mongoose.model('AdminAuditLog', adminAuditLogSchema);
module.exports = AdminAuditLog;
