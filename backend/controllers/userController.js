const Wallet = require('../models/Wallet');
const Bank = require('../models/Bank');
const Kyc = require('../models/Kyc');

// @desc    Get full retailer profile
// @route   GET /api/user/profile
// @access  Private
const getProfile = async (req, res, next) => {
  try {
    const wallet = await Wallet.findOne({ userId: req.user._id });

    res.status(200).json({
      success: true,
      data: req.user.toSafeJSON(),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update retailer profile (non-sensitive fields)
// @route   PUT /api/user/profile
// @access  Private
const updateProfile = async (req, res, next) => {
  try {
    const allowed = [
      'name',
      'email',
      'shopName',
      'shopAddress',
      'city',
      'state',
      'pincode',
      'dob',
      'gender',
    ];
    const updates = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        updates[key] = typeof req.body[key] === 'string'
          ? req.body[key].trim()
          : req.body[key];
      }
    }

    Object.assign(req.user, updates);
    await req.user.save();

    res.status(200).json({
      success: true,
      message: 'Profile updated',
      data: req.user.toSafeJSON(),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get bank details
// @route   GET /api/user/bank
// @access  Private
const getBank = async (req, res, next) => {
  try {
    const bank = await Bank.findOne({ userId: req.user._id });
    res.status(200).json({
      success: true,
      data: bank ? bank.toSafeJSON() : null,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Create / update bank details
// @route   PUT /api/user/bank
// @access  Private
const updateBank = async (req, res, next) => {
  try {
    const { accountHolderName, bankName, accountNumber, ifsc } = req.body;
    if (!accountHolderName || !bankName || !accountNumber || !ifsc) {
      res.status(422);
      throw new Error('All bank fields are required');
    }

    const bank = await Bank.findOneAndUpdate(
      { userId: req.user._id },
      {
        accountHolderName: accountHolderName.trim(),
        bankName: bankName.trim(),
        accountNumber: accountNumber.trim(),
        ifsc: ifsc.trim().toUpperCase(),
        isVerified: false, // re-verify on any change
      },
      { new: true, upsert: true },
    );

    res.status(200).json({
      success: true,
      message: 'Bank details saved',
      data: bank.toSafeJSON(),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get KYC status + identifiers
// @route   GET /api/user/kyc
// @access  Private
const getKyc = async (req, res, next) => {
  try {
    const kyc = await Kyc.findOne({ userId: req.user._id });
    res.status(200).json({
      success: true,
      data: kyc
        ? kyc.toSafeJSON()
        : { status: req.user.kycStatus, documents: [] },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Upload a KYC document
// @route   POST /api/user/kyc/upload
// @access  Private (multipart: field "document", body "type")
const uploadKyc = async (req, res, next) => {
  try {
    if (!req.file) {
      res.status(422);
      throw new Error('No document file provided');
    }
    const type = req.body.type || 'other';
    const url = `/uploads/kyc/${req.file.filename}`;

    const kyc =
      (await Kyc.findOne({ userId: req.user._id })) ||
      (await Kyc.create({ userId: req.user._id, status: 'pending' }));

    kyc.documents.push({ type, url, uploadedAt: new Date() });
    kyc.status = 'pending';
    await kyc.save();

    // Reflect KYC status on the user record too.
    req.user.kycStatus = 'pending';
    await req.user.save();

    res.status(200).json({
      success: true,
      message: 'Document uploaded',
      data: kyc.toSafeJSON(),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Upload avatar
// @route   POST /api/user/profile/avatar
// @access  Private (multipart: field "avatar")
const uploadAvatar = async (req, res, next) => {
  try {
    if (!req.file) {
      res.status(422);
      throw new Error('No image file provided');
    }
    
    const avatarUrl = `/uploads/kyc/${req.file.filename}`; // reusing kyc upload dir for now
    req.user.avatarUrl = avatarUrl;
    await req.user.save();

    res.status(200).json({
      success: true,
      message: 'Avatar uploaded successfully',
      data: req.user.toSafeJSON(),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get recent contacts
// @route   GET /api/user/recent-contacts
// @access  Private
const getRecentContacts = async (req, res, next) => {
  try {
    res.status(200).json({
      success: true,
      data: req.user.recentContacts || [],
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Sync recent contacts
// @route   PUT /api/user/recent-contacts
// @access  Private
const syncRecentContacts = async (req, res, next) => {
  try {
    const { contacts } = req.body;
    if (!Array.isArray(contacts)) {
      res.status(400);
      throw new Error('Contacts must be an array');
    }

    req.user.recentContacts = contacts;
    await req.user.save();

    res.status(200).json({
      success: true,
      message: 'Recent contacts synced successfully',
      data: req.user.recentContacts,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getProfile,
  updateProfile,
  getBank,
  updateBank,
  getKyc,
  uploadKyc,
  uploadAvatar,
  getRecentContacts,
  syncRecentContacts,
};
