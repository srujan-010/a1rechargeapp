const mongoose = require('mongoose');
const ProviderOperator = require('../models/ProviderOperator');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const dthRechargeService = require('../services/dthRecharge.service');
const dthStatusService = require('../services/dthStatus.service');
const walletService = require('../services/wallet/wallet.service');

/**
 * Controller dedicated exclusively to DTH Recharge operations.
 */

// @desc    Execute DTH Recharge
// @route   POST /api/dth/recharge
// @access  Private (Retailer)
const executeDthRecharge = async (req, res, next) => {
  console.log(`[DTH] Controller Entered: executeDthRecharge`);
  let orderId;
  let amountForRollback = 0;
  let walletReserved = false;

  try {
    let subscriberId = req.body.subscriberId || req.body.subscriberNumber || req.body.mobileNumber;
    let { amount, operatorId, amountPaise, mpin, packId, paymentMode = 'wallet' } = req.body;
    const userId = req.user._id;

    if (amountPaise && !amount) {
      amount = amountPaise / 100;
    }

    console.log(`[DTH] Payload received: subscriberId=${subscriberId}, amount=${amount}, operatorId=${operatorId}`);

    // 1. Validate Subscriber ID
    if (!subscriberId || String(subscriberId).trim().length < 8) {
      console.log(`[DTH] Validation Failed: Invalid subscriber ID '${subscriberId}'`);
      return res.status(400).json({
        success: false,
        step: "Subscriber ID Validation",
        error: "Invalid Subscriber ID / VC Number (minimum 8 characters required)",
        details: { subscriberId }
      });
    }

    // 2. Validate Amount
    if (!amount || amount <= 0) {
      console.log(`[DTH] Validation Failed: Invalid amount '${amount}'`);
      return res.status(400).json({
        success: false,
        step: "Amount Validation",
        error: "Invalid recharge amount",
        details: { amount }
      });
    }

    // 3. Validate MPIN
    if (paymentMode === 'wallet') {
      if (!mpin) {
        console.log(`[DTH] Validation Failed: Missing MPIN`);
        return res.status(400).json({
          success: false,
          step: "MPIN Validation",
          error: "MPIN is required for wallet payments"
        });
      }
      const isMpinValid = await req.user.matchMpin(mpin);
      if (!isMpinValid) {
        console.log(`[DTH] Validation Failed: Invalid MPIN`);
        return res.status(400).json({
          success: false,
          step: "MPIN Validation",
          error: "Invalid MPIN entered"
        });
      }
    }

    // 4. Validate DTH Operator
    let operator;
    if (mongoose.Types.ObjectId.isValid(operatorId)) {
      operator = await ProviderOperator.findById(operatorId);
    } else {
      const legacyMap = { 'dth_tata': 'TTV', 'dth_airtel': 'ATV', 'dth_dish': 'DTV', 'dth_videocon': 'VTV', 'dth_sun': 'STV' };
      const mappedCode = legacyMap[String(operatorId).toLowerCase()] || String(operatorId).toUpperCase();
      operator = await ProviderOperator.findOne({ code: mappedCode, provider: 'A1Topup' });
    }

    if (!operator || !operator.status) {
      console.log(`[DTH] Validation Failed: Operator '${operatorId}' not found or inactive`);
      return res.status(400).json({
        success: false,
        step: "Operator Validation",
        error: "Selected DTH Operator is invalid or disabled",
        details: { operatorId }
      });
    }

    console.log(`[DTH] Operator resolved: name=${operator.name}, code=${operator.code}`);

    // 5. Reserve Wallet Funds
    try {
      await walletService.reserveAmount(userId, amount);
      walletReserved = true;
      amountForRollback = amount;
      console.log(`[DTH] Wallet Reserved: ₹${amount}`);
    } catch (wErr) {
      console.log(`[DTH] Wallet Reservation Failed: ${wErr.message}`);
      return res.status(400).json({
        success: false,
        step: "Wallet Reservation",
        error: wErr.message || "Insufficient wallet balance"
      });
    }

    // 6. Create Mongo Pending Documents
    orderId = `A1DTH${Date.now()}${Math.floor(Math.random() * 1000)}`;

    await RechargeTransaction.create({
      orderId,
      userId,
      providerName: 'A1Topup',
      mobileNumber: subscriberId, // subscriberId stored in mobileNumber field for schema compatibility
      amount,
      operatorCode: operator.code,
      circleCode: '4', // DTH doesn't depend on circle; defaulting to 4
      serviceType: 'dth',
      status: 'PENDING',
      reservedAmount: amount,
    });

    await Transaction.create({
      userId,
      type: 'debit',
      amountPaise: Math.round(amount * 100),
      status: 'pending',
      service: 'dth',
      referenceId: orderId,
      description: `DTH Recharge for ${subscriberId} - ${operator.name}`,
      recipientName: subscriberId,
      mobileNumber: subscriberId,
      operatorName: operator.name,
      paymentMethod: paymentMode,
    });

    console.log(`[DTH] Pending Transactions Created in DB with Order ID: ${orderId}`);

    // 7. Process DTH Recharge via DTH Service
    const serviceResult = await dthRechargeService.processDthRecharge({
      orderId,
      subscriberId,
      amount,
      operator,
      userId,
    });

    return res.status(200).json({
      success: true,
      data: {
        transactionId: orderId,
        referenceId: orderId,
        subscriberNumber: subscriberId,
        operatorName: operator.name,
        amountPaise: Math.round(amount * 100),
        status: serviceResult.status.toLowerCase(),
        providerStatus: serviceResult.status,
        providerTransactionId: serviceResult.providerTransactionId,
        operatorReference: serviceResult.operatorReference,
        timestamp: new Date().toISOString(),
        message: serviceResult.message,
      }
    });

  } catch (error) {
    console.error(`[DTH] Controller Error: ${error.message}`);

    // Rollback wallet hold if reserved
    if (walletReserved && userId && amountForRollback > 0) {
      try {
        await walletService.releaseReservation(userId, amountForRollback);
      } catch (rErr) {
        console.error(`[DTH] Wallet Rollback Error: ${rErr.message}`);
      }
    }

    return res.status(500).json({
      success: false,
      error: error.message || 'DTH Recharge Execution Failed'
    });
  }
};

// @desc    Check DTH Recharge Status
// @route   GET /api/dth/status/:orderId
// @access  Private (Retailer)
const checkDthStatus = async (req, res, next) => {
  try {
    const { orderId } = req.params;
    console.log(`[DTH] Controller Entered: checkDthStatus for order ${orderId}`);

    const result = await dthStatusService.checkDthStatus(orderId);
    return res.status(200).json({
      success: true,
      data: {
        orderId: result.orderId,
        status: (result.status || 'pending').toLowerCase(),
        providerStatus: result.providerStatus,
        providerTransactionId: result.providerTransactionId,
        operatorReference: result.operatorReference,
        completedAt: result.completedAt,
      }
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get DTH Transaction History
// @route   GET /api/dth/history
// @access  Private (Retailer)
const getDthHistory = async (req, res, next) => {
  try {
    const userId = req.user._id;
    console.log(`[DTH] Controller Entered: getDthHistory for user ${userId}`);

    const transactions = await Transaction.find({ userId, service: 'dth' })
      .sort({ createdAt: -1 })
      .limit(50);

    return res.status(200).json({
      success: true,
      count: transactions.length,
      data: transactions
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get Active DTH Operators
// @route   GET /api/dth/operators
// @access  Private / Retailer
const getDthOperators = async (req, res, next) => {
  try {
    console.log(`[DTH] Controller Entered: getDthOperators`);
    const operators = await ProviderOperator.find({
      serviceType: /^DTH$/i,
      status: true
    }).sort({ displayOrder: 1, name: 1 });

    return res.status(200).json({
      success: true,
      count: operators.length,
      data: operators
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get DTH Packs for Operator
// @route   GET /api/dth/packs
// @access  Private / Retailer
const getDthPacks = async (req, res, next) => {
  try {
    const { operatorId, search } = req.query;
    console.log(`\n[DTH PACKS] Controller Entered: getDthPacks`);
    console.log(`[DTH PACKS] Query Parameters: operatorId=${operatorId}, search=${search || ''}`);

    if (!operatorId) {
      return res.status(400).json({ success: false, message: 'operatorId is required' });
    }

    // DTH Packs are now directly fetched from the PlanAPI on the frontend
    // Return empty array to support legacy apps
    const packs = [];

    return res.status(200).json({
      success: true,
      service: 'dth',
      type: 'packs',
      data: packs,
      plans: packs
    });
  } catch (error) {
    console.error(`[DTH PACKS] Controller Error: ${error.message}`);
    next(error);
  }
};

module.exports = {
  executeDthRecharge,
  checkDthStatus,
  getDthHistory,
  getDthOperators,
  getDthPacks
};
