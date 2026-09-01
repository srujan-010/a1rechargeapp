const mongoose = require('mongoose');
const ProviderOperator = require('../models/ProviderOperator');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const dthRechargeService = require('../services/dthRecharge.service');
const dthStatusService = require('../services/dthStatus.service');
const walletService = require('../services/wallet/wallet.service');
const { calculateRechargePayableHelper } = require('./recharge.controller');

/**
 * Controller dedicated exclusively to DTH Recharge operations.
 */

// @desc    Execute DTH Recharge
// @route   POST /api/dth/recharge
// @access  Private (Retailer)
const executeDthRecharge = async (req, res, next) => {
  console.log(`[DTH] Controller Entered: executeDthRecharge`);
  let orderId;
  let amountForRollbackPaise = 0;
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

    // 3. Validate Wallet MPIN
    if (paymentMode === 'wallet') {
      const inputMpin = req.body.walletMpin || mpin;
      if (!inputMpin) {
        console.log(`[DTH] Validation Failed: Missing Wallet MPIN`);
        return res.status(400).json({
          success: false,
          step: "MPIN Validation",
          error: "Wallet MPIN is required for wallet payments"
        });
      }
      const isMpinValid = await req.user.matchWalletMpin(inputMpin);
      if (!isMpinValid) {
        console.log(`[DTH] Validation Failed: Invalid Wallet MPIN`);
        return res.status(400).json({
          success: false,
          step: "MPIN Validation",
          error: "Invalid Wallet MPIN entered"
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

    // 5. Calculate Payable Amount & Retailer Commission
    const payableDetails = await calculateRechargePayableHelper({
      serviceType: 'dth',
      operatorCode: operator.code,
      operatorName: operator.name,
      amount,
      userId,
      accountType: req.user?.accountType || 'BUSINESS',
    });

    const grossAmountPaise = payableDetails.grossAmountPaise;
    const commissionAmountPaise = payableDetails.commissionAmountPaise;
    const netPayablePaise = payableDetails.netPayablePaise;

    const commissionAmount = payableDetails.commissionAmount;
    const payableAmount = payableDetails.payableAmount;

    orderId = `A1DTH${Date.now()}${Math.floor(Math.random() * 1000)}`;

    // Reserve ONLY Net Retailer Payable in Wallet (Hold)
    if (paymentMode === 'wallet') {
      try {
        await walletService.reserveWalletAmount({
          userId,
          netPayablePaise,
          orderId,
        });
        walletReserved = true;
        amountForRollbackPaise = netPayablePaise;
        console.log(`[DTH WALLET RESERVED] orderId=${orderId} netPayablePaise=${netPayablePaise} grossPaise=${grossAmountPaise}`);
      } catch (wErr) {
        console.log(`[DTH] Wallet Reservation Failed: ${wErr.message}`);
        return res.status(400).json({
          success: false,
          step: "Wallet Reservation",
          error: wErr.message || "Insufficient wallet balance",
          details: { shortfallPaise: wErr.shortfallPaise }
        });
      }
    }

    // 6. Create Mongo Pending Documents
    await RechargeTransaction.create({
      orderId,
      userId,
      providerName: 'A1Topup',
      mobileNumber: subscriberId,
      grossAmountPaise,
      commissionAmountPaise,
      netPayablePaise,
      reservedAmountPaise: paymentMode === 'wallet' ? netPayablePaise : 0,
      amount: payableDetails.rechargeAmount,
      commissionAmount,
      payableAmount,
      reservedAmount: paymentMode === 'wallet' ? payableAmount : 0,
      accountType: payableDetails.accountType,
      commissionRecordId: payableDetails.commissionRecordId,
      commissionPercent: payableDetails.commissionPercentage,
      operatorCode: operator.code,
      circleCode: '4',
      serviceType: 'dth',
      status: 'PENDING',
      walletSettlementStatus: paymentMode === 'wallet' ? 'PENDING' : 'NONE',
      paymentMethod: paymentMode,
      internalOperatorName: operator.name,
    });

    await Transaction.create({
      userId,
      type: 'debit',
      amountPaise: grossAmountPaise,
      payableAmountPaise: netPayablePaise,
      accountType: payableDetails.accountType,
      commissionRecordId: payableDetails.commissionRecordId,
      commissionEarnedPaise: commissionAmountPaise,
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
        grossAmountPaise,
        commissionAmountPaise,
        netPayablePaise,
        amountPaise: grossAmountPaise,
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

    if (walletReserved && userId && amountForRollbackPaise > 0) {
      try {
        await walletService.releaseOrderHold({ userId, orderId, netPayablePaise: amountForRollbackPaise });
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
    const dbOperators = await ProviderOperator.find({
      serviceType: /^DTH$/i,
      status: true
    }).sort({ displayOrder: 1, name: 1 }).lean();

    const formattedOperators = dbOperators.map(op => {
      let displayName = op.name;
      let a1Code = op.a1TopupCode || op.code;
      let plansCode = op.plansApiCode || op.plansInfoCode || '';

      const codeUpper = String(op.code || op.a1TopupCode || '').toUpperCase().trim();
      const nameUpper = String(op.name || '').toUpperCase().trim();

      if (codeUpper === 'ATV' || nameUpper.includes('AIRTEL')) {
        displayName = 'AIRTEL DTH';
        a1Code = 'ATV';
        plansCode = '24';
      } else if (codeUpper === 'DTV' || nameUpper.includes('DISH')) {
        displayName = 'DISH TV';
        a1Code = 'DTV';
        plansCode = '25';
      } else if (codeUpper === 'RBTV' || nameUpper.includes('RELIANCE')) {
        displayName = 'RELIANCE BIGTV';
        a1Code = 'RBTV';
        plansCode = '26';
      } else if (codeUpper === 'STV' || nameUpper.includes('SUN')) {
        displayName = 'SUN DIRECT';
        a1Code = 'STV';
        plansCode = '27';
      } else if (codeUpper === 'TTV' || nameUpper.includes('TATA')) {
        displayName = 'TATA SKY';
        a1Code = 'TTV';
        plansCode = '28';
      } else if (codeUpper === 'VTV' || nameUpper.includes('VIDEOCON') || nameUpper.includes('D2H')) {
        displayName = 'VIDEOCON D2H';
        a1Code = 'VTV';
        plansCode = '29';
      }

      return {
        id: (op._id || op.name).toString(),
        _id: (op._id || op.name).toString(),
        name: displayName,
        serviceType: op.serviceType || 'DTH',
        code: a1Code,
        a1TopupCode: a1Code,
        plansApiCode: plansCode,
        plansInfoCode: plansCode,
        shortCode: String(a1Code),
        status: op.status,
      };
    });

    return res.status(200).json({
      success: true,
      count: formattedOperators.length,
      data: formattedOperators
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
    if (!operatorId) {
      return res.status(400).json({ success: false, message: 'operatorId is required' });
    }
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
