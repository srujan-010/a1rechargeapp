const Bank = require('../models/Bank');
const User = require('../models/User');

// @desc    Get user bank details
// @route   GET /api/bank
// @access  Private
const getBankDetails = async (req, res, next) => {
  try {
    const bank = await Bank.findOne({ userId: req.user._id });
    if (!bank) {
      return res.status(404).json({ success: true, data: null, message: 'No bank details found' });
    }
    res.status(200).json({ success: true, data: bank.toSafeJSON() });
  } catch (error) {
    next(error);
  }
};

// @desc    Add or Update user bank details
// @route   POST /api/bank
// @access  Private
const addBankDetails = async (req, res, next) => {
  try {
    const { 
      accountHolderName, 
      bankName, 
      accountNumber, 
      ifsc, 
      branch, 
      city, 
      accountType, 
      upiId,
      documentUrl,
      mpin // For security verification if updating
    } = req.body;

    // Basic Validation
    if (!accountHolderName || !bankName || !accountNumber || !ifsc) {
      res.status(400);
      throw new Error('Required fields are missing');
    }

    let bank = await Bank.findOne({ userId: req.user._id });

    // If Bank exists, user is updating. We need MPIN verification.
    if (bank) {
      if (!mpin) {
        res.status(400);
        throw new Error('MPIN is required to update bank details');
      }
      
      const matches = await req.user.matchMpin(mpin);
      if (!matches) {
        res.status(401);
        throw new Error('Invalid MPIN');
      }

      // Update existing bank
      bank.accountHolderName = accountHolderName;
      bank.bankName = bankName;
      bank.accountNumber = accountNumber;
      bank.ifsc = ifsc;
      bank.branch = branch;
      bank.city = city;
      bank.accountType = accountType || 'Savings';
      bank.upiId = upiId;
      if (documentUrl) bank.documentUrl = documentUrl;
      
      // Reset verification status on update
      bank.verificationStatus = 'pending';
      bank.verificationRemarks = undefined;

      await bank.save();

      return res.status(200).json({ 
        success: true, 
        message: 'Bank details updated successfully',
        data: bank.toSafeJSON() 
      });
    }

    // Create new bank details
    bank = await Bank.create({
      userId: req.user._id,
      accountHolderName,
      bankName,
      accountNumber,
      ifsc,
      branch,
      city,
      accountType: accountType || 'Savings',
      upiId,
      documentUrl,
      verificationStatus: 'pending'
    });

    res.status(201).json({ 
      success: true, 
      message: 'Bank details added successfully',
      data: bank.toSafeJSON() 
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Delete user bank details
// @route   DELETE /api/bank
// @access  Private
const deleteBankDetails = async (req, res, next) => {
  try {
    const { mpin } = req.body;
    
    if (!mpin) {
      res.status(400);
      throw new Error('MPIN is required to delete bank details');
    }

    const matches = await req.user.matchMpin(mpin);
    if (!matches) {
      res.status(401);
      throw new Error('Invalid MPIN');
    }

    const bank = await Bank.findOne({ userId: req.user._id });
    if (!bank) {
      res.status(404);
      throw new Error('Bank details not found');
    }

    await bank.deleteOne();

    res.status(200).json({ success: true, message: 'Bank details removed successfully' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getBankDetails,
  addBankDetails,
  deleteBankDetails
};
