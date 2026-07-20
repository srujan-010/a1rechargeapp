const mongoose = require('mongoose');
const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');
const { getCommissionForOperator } = require('./commissionController');
const { calculateCommission } = require('../utils/commissionEngine');

// processRecharge has been moved to recharge.controller.js to use the live A1 Topup provider

// @desc    Process DMT Transfer
// @route   POST /api/services/dmt/transfer
// @access  Private
const processDmtTransfer = async (req, res, next) => {
  try {
    const { beneficiaryId, amountPaise, mode, mpin } = req.body;

    const isMatch = await req.user.matchMpin(mpin);
    if (!isMatch) {
      res.status(401);
      throw new Error('Invalid MPIN');
    }

    // Quick mock for DMT (Not updating fully for now to stay focused on Recharge)
    const wallet = await Wallet.findOne({ userId: req.user._id });
    if (!wallet) throw new Error('Wallet not found');
    if (wallet.balancePaise < amountPaise) {
      const err = new Error('Insufficient balance in wallet');
      err.statusCode = 402;
      throw err;
    }

    wallet.balancePaise -= amountPaise;
    await wallet.save();

    const referenceId = `TXN${Math.floor(Math.random() * 90000000) + 10000000}`;
    await Transaction.create({
      userId: req.user._id,
      type: 'debit',
      amountPaise,
      status: 'success',
      service: 'dmt',
      referenceId,
      closingBalancePaise: wallet.balancePaise,
      description: `DMT Transfer to ${beneficiaryId}`
    });

    res.status(200).json({
      success: true,
      message: 'Transfer successful',
      data: {
        transactionId: referenceId,
        referenceId,
        status: true,
        amountPaise,
        beneficiaryName: 'Mock Beneficiary',
        accountNumber: 'XXXX' + beneficiaryId.substring(beneficiaryId.length - 4),
        mode,
        timestamp: new Date()
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  processDmtTransfer,
};
