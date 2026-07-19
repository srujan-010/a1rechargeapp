const mongoose = require('mongoose');
const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');
const { getCommissionForOperator } = require('./commissionController');
const { calculateCommission } = require('../utils/commissionEngine');

// @desc    Process mobile recharge
// @route   POST /api/services/recharge/initiate
// @access  Private
const processRecharge = async (req, res, next) => {
  let rollbackState = null;
  
  try {
    console.log('[RECHARGE] Incoming Request:', req.body);
    const { mobileNumber, operatorId, operatorName, serviceType = 'mobile', amountPaise, mpin, paymentMode = 'wallet' } = req.body;

    if (!mobileNumber || !operatorId || !amountPaise) {
      const err = new Error('Missing required fields');
      err.statusCode = 400;
      throw err;
    }

    // Verify MPIN only if paymentMode is wallet
    if (paymentMode === 'wallet') {
      if (!mpin) {
        const err = new Error('Missing MPIN');
        err.statusCode = 400;
        throw err;
      }
      console.log('[RECHARGE] Validating MPIN...');
      let isMatch = false;
      try {
        isMatch = await req.user.matchMpin(mpin);
      } catch (e) {
        const err = new Error(e.message);
        err.statusCode = 400;
        throw err;
      }

      if (!isMatch) {
        const err = new Error('Invalid MPIN');
        err.statusCode = 400;
        throw err;
      }
    }

    // Wallet Check
    console.log('[RECHARGE] Checking Wallet...');
    const wallet = await Wallet.findOne({ userId: req.user._id });
    if (!wallet) {
      const err = new Error('Wallet not found');
      err.statusCode = 404;
      throw err;
    }

    if (paymentMode === 'wallet' && wallet.balancePaise < amountPaise) {
      const err = new Error('Insufficient balance in wallet');
      err.statusCode = 402;
      throw err;
    }

    rollbackState = { walletId: wallet._id, originalBalancePaise: wallet.balancePaise };

    // 1. Deduct Wallet (Debit) - ONLY for wallet payment mode
    if (paymentMode === 'wallet') {
      console.log('[RECHARGE] Deducting Wallet Balance...', amountPaise);
      wallet.balancePaise -= amountPaise;
      await wallet.save();
      console.log('[RECHARGE] Wallet Balance After Deduction:', wallet.balancePaise);
    } else {
      console.log('[RECHARGE] UPI Payment detected. Skipping wallet deduction.');
    }

    // Generate references
    const referenceId = `TXN${Math.floor(Math.random() * 90000000) + 10000000}`;
    const apiReference = `OP${Math.floor(Math.random() * 90000000) + 10000000}`;

    // 2. Simulate Provider Call (Success)
    console.log('[RECHARGE] Simulating Provider Request for', operatorId);
    await new Promise(resolve => setTimeout(resolve, 800)); // Simulate network latency

    // 3. Lookup Commission
    const { commissionAmountPaise: commissionEarnedPaise } = calculateCommission(
      serviceType, 
      operatorName || operatorId, 
      amountPaise
    );

    // 4. Credit Commission (if applicable)
    if (commissionEarnedPaise > 0) {
      console.log('[RECHARGE] Crediting Commission...', commissionEarnedPaise);
      wallet.balancePaise += commissionEarnedPaise;
      await wallet.save();
    }
    console.log('[RECHARGE] Final Wallet Balance:', wallet.balancePaise);

    // 5. Save Transactions
    console.log('[RECHARGE] Saving Transactions...');
    
    // Debit txn
    if (paymentMode === 'wallet') {
      const result = await Transaction.create([{
        userId: req.user._id,
        type: 'debit',
        amountPaise,
        status: 'success',
        service: serviceType,
        referenceId,
        closingBalancePaise: wallet.balancePaise - commissionEarnedPaise, // Balance before commission
        mobileNumber: mobileNumber,
        operatorName: operatorName || operatorId,
        apiReference: apiReference,
        commissionEarnedPaise: commissionEarnedPaise,
        description: `Recharge for ${mobileNumber} - ${operatorName || operatorId}`
      }]);
      console.log(`[RECHARGE] Debit Transaction Saved. ID: ${result[0]._id}`);
    } else {
      // For UPI, record the transaction as successful but not debiting wallet
      const result = await Transaction.create([{
        userId: req.user._id,
        type: 'other', // Or 'upi' to indicate it didn't touch wallet balance
        amountPaise,
        status: 'success',
        service: serviceType,
        referenceId,
        closingBalancePaise: wallet.balancePaise - commissionEarnedPaise, 
        mobileNumber: mobileNumber,
        operatorName: operatorName || operatorId,
        apiReference: apiReference,
        commissionEarnedPaise: commissionEarnedPaise,
        description: `UPI Recharge for ${mobileNumber} - ${operatorName || operatorId}`
      }]);
      console.log(`[RECHARGE] UPI Transaction Saved. ID: ${result[0]._id}`);
    }

    // Credit txn (commission)
    if (commissionEarnedPaise > 0) {
      const commReferenceId = `COM${Math.floor(Math.random() * 90000000) + 10000000}`;
      const result = await Transaction.create([{
        userId: req.user._id,
        type: 'credit',
        amountPaise: commissionEarnedPaise,
        status: 'success',
        service: 'commission',
        referenceId: commReferenceId,
        description: `Commission for ${referenceId}`,
        closingBalancePaise: wallet.balancePaise,
      }]);
      console.log(`[RECHARGE] Commission Transaction Saved. ID: ${result[0]._id}`);
    }

    console.log('[RECHARGE] Success! Returning payload.');
    res.status(200).json({
      success: true,
      message: 'Recharge successful',
      data: {
        transactionId: referenceId,
        referenceId,
        operatorRef: apiReference,
        status: 'success',
        amountPaise,
        commissionEarnedPaise: commissionEarnedPaise,
        walletDebitedPaise: paymentMode === 'wallet' ? amountPaise - commissionEarnedPaise : 0,
        walletBalanceAfterPaise: wallet.balancePaise,
        mobileNumber,
        operatorName: (operatorName || operatorId).toUpperCase(),
        timestamp: new Date()
      }
    });
  } catch (error) {
    if (rollbackState) {
      console.error('[RECHARGE] Error:', error.message, 'Rolling back database changes manually.');
      await Wallet.findByIdAndUpdate(rollbackState.walletId, {
        balancePaise: rollbackState.originalBalancePaise
      });
    } else {
      console.error('[RECHARGE] Error:', error.message);
    }
    next(error);
  }
};

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
  processRecharge,
  processDmtTransfer,
};
