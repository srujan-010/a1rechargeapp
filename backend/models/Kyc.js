const mongoose = require('mongoose');
const crypto = require('crypto');

// Encryption configuration
const algorithm = 'aes-256-cbc';
const key = process.env.ENCRYPTION_KEY 
  ? Buffer.from(process.env.ENCRYPTION_KEY, 'hex')
  : crypto.scryptSync('default_development_secret', 'salt', 32); // Fallback for dev

const encrypt = (text) => {
  if (!text) return text;
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(algorithm, key, iv);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return `${iv.toString('hex')}:${encrypted}`;
};

const decrypt = (text) => {
  if (!text || !text.includes(':')) return text;
  try {
    const textParts = text.split(':');
    const iv = Buffer.from(textParts.shift(), 'hex');
    const encryptedText = Buffer.from(textParts.join(':'), 'hex');
    const decipher = crypto.createDecipheriv(algorithm, key, iv);
    let decrypted = decipher.update(encryptedText, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (err) {
    return text; // Return as is if decryption fails (e.g., previously unencrypted data)
  }
};

const kycSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    fullName: {
      type: String,
      trim: true,
    },
    dob: {
      type: String, // YYYY-MM-DD
      trim: true,
    },
    address: {
      type: String,
      trim: true,
    },
    aadhaarNumber: {
      type: String,
      trim: true,
    },
    panNumber: {
      type: String,
      trim: true,
      uppercase: true,
    },
    gstNumber: {
      type: String,
      trim: true,
      uppercase: true,
    },
    shopName: {
      type: String,
      trim: true,
    },
    businessType: {
      type: String,
      trim: true,
    },
    // Document URLs
    aadhaarFront: { type: String, trim: true },
    aadhaarBack: { type: String, trim: true },
    panImage: { type: String, trim: true },
    shopPhoto: { type: String, trim: true },
    selfie: { type: String, trim: true },
    
    status: {
      type: String,
      enum: ['notStarted', 'pending', 'verified', 'rejected', 'underReview'],
      default: 'notStarted',
    },
    submittedAt: { type: Date },
    approvedAt: { type: Date },
    rejectedAt: { type: Date },
    verifiedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    remarks: { type: String, trim: true },
  },
  { timestamps: true },
);

// Pre-save hook to encrypt sensitive fields
kycSchema.pre('save', async function () {
  if (this.isModified('aadhaarNumber') && this.aadhaarNumber && !this.aadhaarNumber.includes(':')) {
    this.aadhaarNumber = encrypt(this.aadhaarNumber);
  }
  if (this.isModified('panNumber') && this.panNumber && !this.panNumber.includes(':')) {
    this.panNumber = encrypt(this.panNumber);
  }
});

// Method to mask government IDs for client responses
kycSchema.methods.toSafeJSON = function toSafeJSON() {
  const maskAadhaar = (v) => {
    if (!v) return null;
    const decrypted = decrypt(v);
    if (decrypted.length === 12) {
      return `XXXX XXXX ${decrypted.slice(-4)}`;
    }
    return decrypted.length > 4 ? `XXXX${decrypted.slice(-4)}` : decrypted;
  };
  
  const maskPan = (v) => {
    if (!v) return null;
    const decrypted = decrypt(v);
    if (decrypted.length === 10) {
      return `${decrypted.slice(0, 5)}****${decrypted.slice(-1)}`;
    }
    return decrypted.length > 4 ? `XXXX${decrypted.slice(-4)}` : decrypted;
  };

  return {
    fullName: this.fullName,
    dob: this.dob,
    address: this.address,
    aadhaarNumber: maskAadhaar(this.aadhaarNumber),
    panNumber: maskPan(this.panNumber),
    gstNumber: this.gstNumber,
    shopName: this.shopName,
    businessType: this.businessType,
    aadhaarFront: this.aadhaarFront,
    aadhaarBack: this.aadhaarBack,
    panImage: this.panImage,
    shopPhoto: this.shopPhoto,
    selfie: this.selfie,
    status: this.status,
    remarks: this.remarks,
    submittedAt: this.submittedAt,
    approvedAt: this.approvedAt,
    rejectedAt: this.rejectedAt,
  };
};

const Kyc = mongoose.model('Kyc', kycSchema);

module.exports = Kyc;
