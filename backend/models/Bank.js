const mongoose = require('mongoose');

const bankSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    accountHolderName: {
      type: String,
      required: true,
      trim: true,
    },
    bankName: {
      type: String,
      required: true,
      trim: true,
    },
    accountNumber: {
      type: String,
      required: true,
      trim: true,
    },
    ifsc: {
      type: String,
      required: true,
      trim: true,
      uppercase: true,
    },
    branch: {
      type: String,
      trim: true,
    },
    city: {
      type: String,
      trim: true,
    },
    accountType: {
      type: String,
      enum: ['Savings', 'Current'],
      default: 'Savings',
    },
    upiId: {
      type: String,
      trim: true,
    },
    verificationStatus: {
      type: String,
      enum: ['pending', 'verified', 'rejected'],
      default: 'pending',
    },
    verificationRemarks: {
      type: String,
      trim: true,
    },
    documentUrl: {
      type: String,
      trim: true,
    }
  },
  { timestamps: true },
);

// Mask all but the last 4 digits of the account number for client responses.
bankSchema.methods.toSafeJSON = function toSafeJSON() {
  const acc = this.accountNumber ?? '';
  const masked =
    acc.length > 4 ? `XXXX${acc.slice(-4)}` : acc;
  return {
    accountHolderName: this.accountHolderName,
    bankName: this.bankName,
    accountNumber: masked,
    ifsc: this.ifsc,
    branch: this.branch,
    city: this.city,
    accountType: this.accountType,
    upiId: this.upiId,
    verificationStatus: this.verificationStatus,
    verificationRemarks: this.verificationRemarks,
    documentUrl: this.documentUrl,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

const Bank = mongoose.model('Bank', bankSchema);

module.exports = Bank;
