const Kyc = require('../models/Kyc');
const Notification = require('../models/Notification');

// @desc    Get user KYC details
// @route   GET /api/kyc
// @access  Private
const getKycDetails = async (req, res, next) => {
  try {
    let kyc = await Kyc.findOne({ userId: req.user._id });
    if (!kyc) {
      kyc = await Kyc.create({ userId: req.user._id, status: 'notStarted' });
    }
    res.status(200).json({ success: true, data: kyc.toSafeJSON() });
  } catch (error) {
    next(error);
  }
};

// @desc    Submit or update user KYC details
// @route   POST /api/kyc (and PUT /api/kyc)
// @access  Private
const submitKycDetails = async (req, res, next) => {
  try {
    const {
      fullName,
      dob,
      address,
      aadhaarNumber,
      panNumber,
      gstNumber,
      shopName,
      businessType,
      aadhaarFront,
      aadhaarBack,
      panImage,
      shopPhoto,
      selfie,
      isFinalSubmit, // flag from frontend to actually push to "underReview"
    } = req.body;

    let kyc = await Kyc.findOne({ userId: req.user._id });
    if (!kyc) {
      kyc = new Kyc({ userId: req.user._id });
    }

    // Don't allow edits if verified or under review (unless rejected/pending)
    if (kyc.status === 'verified' || kyc.status === 'underReview') {
      res.status(400);
      throw new Error('KYC is currently under review or already verified. Modifications not allowed.');
    }

    // Update fields if provided
    if (fullName) kyc.fullName = fullName;
    if (dob) kyc.dob = dob;
    if (address) kyc.address = address;
    if (aadhaarNumber) kyc.aadhaarNumber = aadhaarNumber; // pre-save hook encrypts this
    if (panNumber) kyc.panNumber = panNumber; // pre-save hook encrypts this
    if (gstNumber) kyc.gstNumber = gstNumber;
    if (shopName) kyc.shopName = shopName;
    if (businessType) kyc.businessType = businessType;

    // Documents
    if (aadhaarFront) kyc.aadhaarFront = aadhaarFront;
    if (aadhaarBack) kyc.aadhaarBack = aadhaarBack;
    if (panImage) kyc.panImage = panImage;
    if (shopPhoto) kyc.shopPhoto = shopPhoto;
    if (selfie) kyc.selfie = selfie;

    // Handle status progression
    if (isFinalSubmit) {
      // Check required fields before allowing final submit
      if (!kyc.fullName || !kyc.dob || !kyc.address || !kyc.aadhaarNumber || !kyc.panNumber || 
          !kyc.aadhaarFront || !kyc.aadhaarBack || !kyc.panImage || !kyc.selfie || 
          !kyc.shopName || !kyc.shopPhoto) {
        res.status(400);
        throw new Error('All required KYC fields must be completed before submission.');
      }
      kyc.status = 'underReview';
      kyc.submittedAt = new Date();
      kyc.remarks = undefined; // clear old rejection remarks
    } else {
      // Just saving draft
      if (kyc.status === 'notStarted' || kyc.status === 'rejected') {
        kyc.status = 'pending'; // meaning "draft in progress"
      }
    }

    await kyc.save();

    if (isFinalSubmit) {
      await Notification.create({
        userId: req.user._id,
        title: 'KYC Submitted',
        message: 'Your KYC documents have been submitted and are under review. You will be notified once approved.',
        category: 'INFO',
        priority: 'NORMAL',
        action: 'ROUTE_KYC'
      });
    }

    res.status(200).json({ 
      success: true, 
      message: isFinalSubmit ? 'KYC submitted successfully' : 'KYC draft saved',
      data: kyc.toSafeJSON() 
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get user KYC status only (lightweight)
// @route   GET /api/kyc/status
// @access  Private
const getKycStatus = async (req, res, next) => {
  try {
    let kyc = await Kyc.findOne({ userId: req.user._id }).select('status remarks submittedAt approvedAt rejectedAt');
    if (!kyc) {
      kyc = { status: 'notStarted' };
    }
    res.status(200).json({ success: true, data: kyc });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getKycDetails,
  submitKycDetails,
  getKycStatus
};
