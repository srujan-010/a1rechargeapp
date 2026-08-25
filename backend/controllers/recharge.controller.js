const a1TopupProvider = require('../services/providers/a1topup/provider.service');
const fast2smsService = require('../services/fast2sms.service');
const notificationService = require('../services/notification.service');
const { resolveProviderOperatorCode, isBsnlOperator } = require('../utils/operatorMapper');

const ProviderWallet = require('../models/ProviderWallet');
const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
const User = require('../models/User');
const mongoose = require('mongoose');

// @desc    Check health of the A1 Topup provider
// @route   GET /api/provider/a1topup/health
// @access  Private (Admin only)
const checkProviderHealth = async (req, res, next) => {
  try {
    const healthStatus = await a1TopupProvider.health();

    if (!healthStatus.success) {
      res.status(503);
      throw new Error(`Provider Health Check Failed: ${healthStatus.message}`);
    }

    res.status(200).json({
      success: true,
      data: healthStatus,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Check and update balance of the A1 Topup provider
// @route   GET /api/provider/a1topup/balance
// @access  Private (Admin only)
const checkProviderBalance = async (req, res, next) => {
  try {
    const balanceData = await a1TopupProvider.balance();

    // Update Provider Wallet in DB
    let wallet = await ProviderWallet.findOne({ providerName: 'A1Topup' });
    if (!wallet) {
      wallet = new ProviderWallet({ providerName: 'A1Topup' });
    }

    wallet.balance = balanceData.balance;
    wallet.currency = balanceData.currency;
    wallet.lastCheckedAt = Date.now();
    await wallet.save();

    res.status(200).json({
      success: true,
      data: {
        providerName: wallet.providerName,
        balance: wallet.balance,
        currency: wallet.currency,
        lastCheckedAt: wallet.lastCheckedAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Fetch supported operators from provider
// @route   GET /api/provider/a1topup/operators
// @access  Private (Admin only)
const getOperators = async (req, res, next) => {
  try {
    const operatorsData = await a1TopupProvider.operators();
    res.status(200).json(operatorsData);
  } catch (error) {
    next(error);
  }
};

// @desc    Fetch plans from provider
// @route   GET /api/provider/a1topup/plans
// @access  Private (Admin only)
const getPlans = async (req, res, next) => {
  try {
    const { operator, circle } = req.query;
    if (!operator || !circle) {
      res.status(400);
      throw new Error('Operator and circle are required to fetch plans');
    }
    const plansData = await a1TopupProvider.plans(operator, circle);
    res.status(200).json(plansData);
  } catch (error) {
    next(error);
  }
};

const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const CommissionHistory = require('../models/CommissionHistory');
const walletService = require('../services/wallet/wallet.service');
const commissionService = require('../services/commission/commission.service');
const ledgerService = require('../services/ledger/ledger.service');
const crypto = require('crypto');
const Razorpay = require('razorpay');
const { getRazorpayKeyId } = require('../config/walletConfig');

/**
 * Initialize Razorpay instance for recharge orders
 */
const getRazorpayInstance = () => {
  const key_id = (process.env.RAZORPAY_KEY_ID || '').trim();
  const key_secret = (process.env.RAZORPAY_KEY_SECRET || '').trim();
  if (!key_id || !key_secret) {
    throw new Error('Razorpay credentials missing in environment');
  }
  return new Razorpay({ key_id, key_secret });
};

/**
 * Calculate payable amount and commission breakdown server-side
 */
const calculateRechargePayableHelper = async ({ serviceType = 'mobile', operatorCode, operatorName, amount, userId, planType, accountType = 'BUSINESS' }) => {
  const safeAmount = Number.isFinite(Number(amount)) ? Number(amount) : 0;

  let resolvedAccountType = accountType;
  if (userId && mongoose.Types.ObjectId.isValid(userId)) {
    const userQuery = User.findById(userId);
    const userDoc = userQuery && typeof userQuery.lean === 'function' ? await userQuery.lean() : await userQuery;
    if (userDoc && userDoc.accountType) {
      resolvedAccountType = userDoc.accountType;
    }
  }
  const targetAccountType = String(resolvedAccountType || 'BUSINESS').trim().toUpperCase() === 'PERSONAL' ? 'PERSONAL' : 'BUSINESS';

  if (safeAmount <= 0) {
    return {
      accountType: targetAccountType,
      commissionRecordId: null,
      rechargeAmount: 0,
      rechargeAmountPaise: 0,
      commissionAmount: 0,
      commissionAmountPaise: 0,
      commissionPercentage: 0,
      payableAmount: 0,
      payableAmountPaise: 0,
      currency: 'INR',
    };
  }

  const commission = await commissionService.calculateCommission(
    operatorCode,
    safeAmount,
    operatorName,
    serviceType,
    { retailerId: userId ? String(userId) : 'N/A', planType, accountType: targetAccountType }
  );

  const safeVal = (v) => {
    const n = Number(v);
    return Number.isFinite(n) ? Number(n.toFixed(2)) : 0;
  };

  const isPersonal = targetAccountType === 'PERSONAL';

  const commissionAmount = isPersonal
    ? safeVal(commission?.personalDiscountAmount)
    : safeVal(commission?.retailerCommissionAmount);

  const commissionPercentage = isPersonal
    ? safeVal(commission?.personalCommissionPercentage)
    : safeVal(commission?.retailerCommissionPercentage);

  const payableAmount = safeVal(Math.max(0, safeAmount - commissionAmount));

  return {
    accountType: targetAccountType,
    commissionRecordId: commission?.commissionRecordId || null,
    rechargeAmount: safeAmount,
    rechargeAmountPaise: Math.round(safeAmount * 100),
    commissionAmount,
    commissionAmountPaise: Math.round(commissionAmount * 100),
    commissionPercentage,
    payableAmount,
    payableAmountPaise: Math.round(payableAmount * 100),
    currency: 'INR',
  };
};

/**
 * Process retailer commission and record CommissionHistory safely and idempotently
 */
const processSuccessCommission = async ({ transaction, globalTransaction, userId, orderId, mobileNumber, operator, operatorCode, amount, planType, serviceType = 'mobile' }) => {
  try {
    // Prevent Duplicate Commission (Idempotency Guard)
    if (transaction.commissionCalculated) {
      console.log(`[COMMISSION IDEMPOTENT] Commission already processed for orderId ${orderId}. Skipping duplicate credit.`);
      return;
    }

    const existingHist = await CommissionHistory.findOne({ transactionId: transaction._id }).catch(() => null);
    if (existingHist) {
      transaction.commissionCalculated = true;
      await transaction.save().catch(() => { });
      console.log(`[COMMISSION IDEMPOTENT] CommissionHistory record already exists for orderId ${orderId}. Skipping duplicate credit.`);
      return;
    }

    // Commission Lookup & Calculation
    const commission = await commissionService.calculateCommission(
      operatorCode,
      amount,
      operator ? operator.name : (transaction.internalOperatorName || ''),
      serviceType,
      {
        orderId,
        retailerId: userId ? userId.toString() : 'N/A',
        operatorId: transaction.internalOperatorId || 'N/A',
        planType: planType || transaction.planType || 'N/A',
      }
    );

    const safeVal = (v) => {
      const n = Number(v);
      return Number.isFinite(n) ? Number(n.toFixed(2)) : 0;
    };

    const providerCommissionPercent = safeVal(commission?.providerCommissionPercentage);
    const providerCommissionAmount = safeVal(commission?.providerCommissionAmount);
    const retailerCommissionPercent = safeVal(commission?.retailerCommissionPercentage);
    const retailerCommissionAmount = safeVal(commission?.retailerCommissionAmount);
    const companyProfitPercent = safeVal(commission?.companyProfitPercentage);
    const companyProfitAmount = safeVal(commission?.companyProfitAmount);

    // CRITICAL REQUIREMENT 17: Assert finite numeric values before saving to MongoDB
    if (!Number.isFinite(providerCommissionAmount) || !Number.isFinite(retailerCommissionAmount)) {
      console.error(`[COMMISSION CRITICAL ERROR] Invalid commission amounts calculated for orderId ${orderId}: provider=${providerCommissionAmount}, retailer=${retailerCommissionAmount}`);
      throw new Error(`Commission calculation returned NaN/invalid number for order ${orderId}`);
    }

    let ledgerEntryId = 'N/A';

    // Log to ledger for auditing
    if (retailerCommissionAmount > 0) {
      const ledgerLog = await ledgerService.logTransaction({
        userId,
        type: 'CREDIT',
        amount: retailerCommissionAmount,
        referenceType: 'COMMISSION',
        referenceId: transaction._id,
        description: `Commission for Recharge ${orderId}`,
      }).catch(e => { console.error('[Ledger Credit Warning]:', e.message); return null; });

      if (ledgerLog && ledgerLog._id) {
        ledgerEntryId = ledgerLog._id.toString();
      }
    }

    // Save CommissionHistory Record strictly with finite numbers
    await CommissionHistory.create({
      transactionId: transaction._id,
      userId,
      operatorCode: String(operatorCode || 'UNKNOWN'),
      rechargeAmount: safeVal(amount),
      providerCommissionPercentage: providerCommissionPercent,
      providerCommissionAmount: providerCommissionAmount,
      retailerCommissionPercentage: retailerCommissionPercent,
      retailerCommissionAmount: retailerCommissionAmount,
      companyProfitPercentage: companyProfitPercent,
      companyProfitAmount: companyProfitAmount,
    });

    transaction.commissionCalculated = true;
    await transaction.save().catch(() => { });

    if (globalTransaction) {
      globalTransaction.commissionEarnedPaise = Math.round(retailerCommissionAmount * 100);
      await globalTransaction.save().catch(() => { });
    }

    console.log('\n====================================================');
    console.log('[COMMISSION HISTORY CREATED SUCCESSFULLY]');
    console.log(`orderId: ${orderId}`);
    console.log(`retailerId: ${userId}`);
    console.log(`rechargeAmount: ${amount}`);
    console.log(`retailerCommissionAmount: ${retailerCommissionAmount}`);
    console.log('====================================================\n');

  } catch (err) {
    console.error(`[COMMISSION PROCESSING ERROR] orderId=${orderId}:`, err.message);
  }
};

// @desc    Calculate Payable Amount and Commission preview server-side
// @route   POST /api/provider/a1topup/calculate-payable
// @access  Private
const calculateRechargePayable = async (req, res, next) => {
  try {
    let { serviceType = 'mobile', operatorCode, operatorName, operatorId, circle, circleId, amount, amountPaise, planType } = req.body;
    if (amountPaise && !amount) amount = amountPaise / 100;
    amount = amount || 0;

    let operator;
    if (mongoose.Types.ObjectId.isValid(operatorId)) {
      operator = await ProviderOperator.findById(operatorId);
    }
    if (!operator && operatorId) {
      const codeLookup = String(operatorId || '').toUpperCase().trim();
      operator = await ProviderOperator.findOne({ code: codeLookup });
    }
    if (!operator && (operatorName || operatorId)) {
      const searchKey = String(operatorName || operatorId).trim().split(' ')[0];
      operator = await ProviderOperator.findOne({ name: new RegExp(searchKey, 'i') });
    }

    const resolvedCode = operator ? operator.code : (operatorCode || operatorId);
    const resolvedName = operator ? operator.name : operatorName;

    const userAccountType = (req.user && req.user.accountType) ? String(req.user.accountType).toUpperCase() : 'RETAILER';

    const details = await calculateRechargePayableHelper({
      serviceType,
      operatorCode: resolvedCode,
      operatorName: resolvedName,
      amount,
      userId: req.user._id,
      planType,
      accountType: userAccountType,
    });

    console.log('\n====================================================');
    console.log('[COMMISSION DEBUG]');
    console.log(`accountType: ${userAccountType}`);
    console.log(`serviceType: ${serviceType}`);
    console.log(`operator: ${resolvedName || 'N/A'}`);
    console.log(`rechargeAmount: ${amount}`);
    console.log(`Calculated payableAmount: ${details.payableAmount}`);
    console.log('====================================================\n');

    res.status(200).json({
      success: true,
      data: details,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Create Razorpay Order for Recharge (Server-side commission & payable calculation)
// @route   POST /api/provider/a1topup/create-razorpay-order
// @access  Private (Retailer)
const createRazorpayRechargeOrder = async (req, res, next) => {
  let transaction;
  let globalTransaction;
  try {
    const userId = req.user._id;
    let mobileNumber = req.body.mobileNumber || req.body.phoneNumber || req.body.subscriberNumber || 'N/A';
    let {
      amount,
      amountPaise,
      operatorId,
      circleId,
      serviceType = 'mobile',
      planId,
      planName,
      planType,
      selectedCategory,
      providerOperatorCode: reqProviderOpCode,
    } = req.body;

    if (amountPaise && !amount) {
      amount = amountPaise / 100;
    }
    amount = amount || 0;

    if (!mobileNumber || mobileNumber === 'N/A' || !amount || amount <= 0 || !operatorId) {
      return res.status(400).json({
        success: false,
        code: 'INVALID_PAYLOAD',
        message: 'Missing or invalid required fields for recharge order creation.',
      });
    }

    // Resolve Provider Mapping
    let operator;
    if (mongoose.Types.ObjectId.isValid(operatorId)) {
      operator = await ProviderOperator.findById(operatorId);
    }
    if (!operator) {
      const codeLookup = String(operatorId || '').toUpperCase().trim();
      operator = await ProviderOperator.findOne({ code: codeLookup, provider: 'A1Topup' });
    }
    if (!operator) {
      const firstWord = String(req.body.operatorName || '').trim().split(' ')[0];
      operator = await ProviderOperator.findOne({ name: new RegExp(firstWord, 'i'), provider: 'A1Topup' });
    }
    if (!operator || !operator.status) {
      return res.status(400).json({
        success: false,
        code: 'INVALID_OPERATOR',
        message: `Invalid or disabled operator ID '${operatorId}'`,
      });
    }

    let operatorCode = operator.code;
    const providerOperatorCode = resolveProviderOperatorCode({
      operator,
      operatorId,
      operatorName: req.body.operatorName || operator.name,
      planType,
      selectedCategory,
      planName,
      providerOperatorCode: reqProviderOpCode,
    });
    if (operator.serviceType?.toUpperCase() !== 'DTH' && serviceType !== 'dth') {
      operatorCode = providerOperatorCode;
    }

    let circle;
    if (circleId && mongoose.Types.ObjectId.isValid(circleId)) {
      circle = await ProviderCircle.findById(circleId);
    } else {
      circle = await ProviderCircle.findOne({ code: '4', provider: 'A1Topup' });
    }
    const circleCode = circle ? circle.code : '4';

    // Calculate Commission & Net Payable Amount
    const payableDetails = await calculateRechargePayableHelper({
      serviceType,
      operatorCode,
      operatorName: req.body.operatorName || operator.name,
      amount,
      userId,
      planType,
    });

    const payableAmount = payableDetails.payableAmount;
    const payableAmountPaise = payableDetails.payableAmountPaise;
    const commissionAmount = payableDetails.commissionAmount;

    if (!Number.isFinite(payableAmountPaise) || payableAmountPaise < 0) {
      return res.status(400).json({
        success: false,
        code: 'COMMISSION_CALCULATION_ERROR',
        message: 'Commission calculation produced an invalid payable amount. Please try again.',
      });
    }

    const orderId = `A1R${Date.now()}${Math.floor(Math.random() * 1000)}`;

    // Create Razorpay SDK order for payableAmountPaise (e.g., 9800 paise for ₹98 payable)
    const razorpay = getRazorpayInstance();
    const razorpayOrder = await razorpay.orders.create({
      amount: payableAmountPaise,
      currency: 'INR',
      receipt: orderId,
      notes: {
        internalTransactionId: orderId,
        retailerId: userId.toString(),
        userId: userId.toString(),
        serviceType,
        operatorId: String(operatorId),
        circleId: String(circleId),
        rechargeAmount: amount,
        commissionAmount,
        payableAmount,
      },
    });

    // Create internal RechargeTransaction record in PAYMENT_PENDING state
    transaction = await RechargeTransaction.create({
      orderId,
      clientOrderId: orderId,
      userId,
      providerName: 'A1Topup',
      mobileNumber,
      amount,
      accountType: payableDetails.accountType,
      commissionRecordId: payableDetails.commissionRecordId,
      commissionPercent: payableDetails.commissionPercentage,
      commissionAmount,
      payableAmount,
      operatorCode,
      circleCode,
      status: 'PAYMENT_PENDING',
      paymentMethod: 'RAZORPAY_UPI',
      razorpayOrderId: razorpayOrder.id,
      operatorId: String(operatorId),
      serviceType,
      planId: planId || null,
      planName: planName || null,
      planType: planType || null,
      providerOperatorCode,
      internalOperatorId: String(operatorId),
      internalOperatorName: req.body.operatorName || operator.name,
    });

    globalTransaction = await Transaction.create({
      userId,
      type: 'debit',
      amountPaise: Math.round(amount * 100),
      payableAmountPaise,
      accountType: payableDetails.accountType,
      commissionRecordId: payableDetails.commissionRecordId,
      commissionEarnedPaise: Math.round(commissionAmount * 100),
      status: 'initiated',
      service: serviceType === 'dth' ? 'dth' : 'mobile_recharge',
      referenceId: orderId,
      description: `Recharge for ${mobileNumber} - ${operator.name}`,
      recipientName: mobileNumber,
      mobileNumber: mobileNumber,
      operatorName: operator.name,
      operatorId: String(operatorId),
      paymentMethod: 'razorpay',
      razorpayOrderId: razorpayOrder.id,
    });

    console.log(`[RAZORPAY RECHARGE ORDER CREATED] orderId=${orderId}, razorpayOrderId=${razorpayOrder.id}, rechargeAmount=${amount}, payableAmount=${payableAmount}`);

    return res.status(200).json({
      success: true,
      message: 'Razorpay order created for recharge',
      data: {
        internalTransactionId: orderId,
        razorpayOrderId: razorpayOrder.id,
        razorpayKeyId: getRazorpayKeyId(),
        rechargeAmount: amount,
        rechargeAmountPaise: Math.round(amount * 100),
        commissionAmount,
        commissionAmountPaise: Math.round(commissionAmount * 100),
        payableAmount,
        payableAmountPaise,
        currency: 'INR',
      },
    });
  } catch (error) {
    console.error('[RAZORPAY RECHARGE ORDER ERROR]:', error);
    next(error);
  }
};

/**
 * UNIFIED A1TOPUP RECHARGE EXECUTION ENGINE
 * Shared between Wallet Recharge and Razorpay/UPI Recharge
 */
const dispatchA1TopupRecharge = async ({ transaction, globalTransaction, userId }) => {
  console.log('\n====================================================');
  console.log('[A1TOPUP RECHARGE INITIATION STARTED]');
  console.log(`internalTransactionId: ${transaction.orderId}`);
  console.log(`paymentMethod: ${transaction.paymentMethod}`);
  console.log(`mobileNumber: ${transaction.mobileNumber}`);
  console.log(`rechargeAmount: ${transaction.amount}`);
  console.log(`payableAmount: ${transaction.payableAmount}`);
  console.log(`commissionAmount: ${transaction.commissionAmount}`);
  console.log(`operatorCode: ${transaction.operatorCode}`);
  console.log(`circleCode: ${transaction.circleCode}`);
  console.log(`serviceType: ${transaction.serviceType}`);
  console.log('====================================================\n');

  transaction.providerRequestSent = true;
  transaction.status = 'RECHARGE_PROCESSING';
  await transaction.save();

  if (globalTransaction) {
    globalTransaction.status = 'pending';
    await globalTransaction.save();
  }

  // Execute HTTP GET request to A1Topup provider /recharge/api
  const providerResponse = await a1TopupProvider.recharge({
    orderId: transaction.orderId,
    mobileNumber: transaction.mobileNumber,
    amount: transaction.amount, // Full ₹100 recharge value
    operatorCode: transaction.operatorCode,
    circleCode: transaction.circleCode,
    serviceType: transaction.serviceType,
  });

  console.log(`[A1TOPUP RECHARGE INITIATION RESPONSE] orderId=${transaction.orderId}, status=${providerResponse.status}, providerTransactionId=${providerResponse.providerTransactionId || 'N/A'}`);

  transaction.providerTransactionId = providerResponse.providerTransactionId || null;
  transaction.operatorReference = providerResponse.operatorReference || null;
  transaction.status = providerResponse.status;
  transaction.providerStatus = providerResponse.status;
  transaction.providerMessage = providerResponse.message || null;

  if (globalTransaction) {
    globalTransaction.providerTransactionId = providerResponse.providerTransactionId || null;
    globalTransaction.providerMessage = providerResponse.message || null;
  }

  if (providerResponse.status === 'SUCCESS' || providerResponse.status === 'FAILED') {
    transaction.completedAt = new Date();
    if (globalTransaction) globalTransaction.completedAt = new Date();
  }

  if (providerResponse.status === 'SUCCESS') {
    // Commit wallet hold ONLY IF wallet payment
    if (transaction.paymentMethod === 'WALLET' || transaction.paymentMethod === 'wallet') {
      await walletService.commitReservation(userId, transaction.payableAmount || transaction.amount).catch(e => console.error('[Wallet Commit Warning]:', e.message));
    }

    await processSuccessCommission({
      transaction,
      globalTransaction,
      userId,
      orderId: transaction.orderId,
      mobileNumber: transaction.mobileNumber,
      operator: { name: transaction.internalOperatorName },
      operatorCode: transaction.operatorCode,
      amount: transaction.amount,
      planType: transaction.planType,
      serviceType: transaction.serviceType,
    });

    if (globalTransaction) {
      globalTransaction.status = 'success';
      globalTransaction.apiReference = providerResponse.providerTransactionId;
      await globalTransaction.save();
    }

    notificationService.sendRechargeSuccess({
      userId,
      transactionId: providerResponse.providerTransactionId || transaction.orderId,
      orderId: transaction.orderId,
      operator: transaction.internalOperatorName || 'Operator',
      amount: transaction.amount,
      number: transaction.mobileNumber,
      commissionAmount: transaction.commissionAmount,
    });

    if (transaction.commissionAmount && Number(transaction.commissionAmount) > 0) {
      notificationService.notifyCommissionEarned({
        userId,
        commissionAmount: transaction.commissionAmount,
      });
    }

  } else if (providerResponse.status === 'FAILED') {
    transaction.failureReason = providerResponse.message || 'Recharge failed at provider';
    if (globalTransaction) {
      globalTransaction.status = 'failed';
      globalTransaction.failureReason = transaction.failureReason;
      await globalTransaction.save();
    }

    if (transaction.paymentMethod === 'WALLET' || transaction.paymentMethod === 'wallet') {
      await walletService.releaseReservation(userId, transaction.payableAmount || transaction.amount).catch(e => console.error('[Wallet Release Warning]:', e.message));
    } else if (transaction.razorpayPaymentId) {
      // Auto-refund Razorpay payment for net payable amount
      try {
        const razorpay = getRazorpayInstance();
        const payablePaise = Math.round((transaction.payableAmount || transaction.amount) * 100);
        await razorpay.payments.refund(transaction.razorpayPaymentId, {
          amount: payablePaise,
          notes: { reason: 'Recharge failed at provider', orderId: transaction.orderId },
        });
        transaction.status = 'REFUNDED';
        if (globalTransaction) globalTransaction.status = 'reversed';
        console.log(`[RAZORPAY REFUND SUCCESS] Refunded ${payablePaise} paise for payment ${transaction.razorpayPaymentId}`);
      } catch (rfErr) {
        console.error(`[RAZORPAY REFUND ERROR] Failed to auto-refund ${transaction.razorpayPaymentId}:`, rfErr.message);
      }
    }

    notificationService.sendRechargeFailed({
      userId,
      transactionId: providerResponse.providerTransactionId || transaction.orderId,
      orderId: transaction.orderId,
      operator: transaction.internalOperatorName || 'Operator',
      amount: transaction.amount,
      number: transaction.mobileNumber,
      reason: transaction.failureReason,
    });

  } else if (providerResponse.status === 'PENDING') {
    if (globalTransaction) {
      globalTransaction.status = 'pending';
      globalTransaction.apiReference = providerResponse.providerTransactionId;
      await globalTransaction.save();
    }

    notificationService.sendRechargePending({
      userId,
      transactionId: providerResponse.providerTransactionId || transaction.orderId,
      orderId: transaction.orderId,
      operator: transaction.internalOperatorName || 'Operator',
      amount: transaction.amount,
      number: transaction.mobileNumber,
    });

    const rechargePoller = require('../utils/rechargePoller');
    rechargePoller.startPolling(transaction.orderId);
  }

  await transaction.save();
  return providerResponse;
};

// @desc    Verify Razorpay Payment and Execute Recharge
// @route   POST /api/provider/a1topup/verify-razorpay-payment
// @access  Private (Retailer)
const verifyRazorpayRechargePayment = async (req, res, next) => {
  const { internalTransactionId, razorpayOrderId, razorpayPaymentId, razorpaySignature } = req.body;
  const userId = req.user._id;

  if (!internalTransactionId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
    return res.status(400).json({
      success: false,
      code: 'MISSING_PAYMENT_DETAILS',
      message: 'Missing required Razorpay payment details for verification.',
    });
  }

  try {
    const transaction = await RechargeTransaction.findOne({
      orderId: internalTransactionId,
      userId,
    });

    if (!transaction) {
      return res.status(404).json({
        success: false,
        code: 'TRANSACTION_NOT_FOUND',
        message: 'Recharge transaction record not found.',
      });
    }

    const globalTransaction = await Transaction.findOne({ referenceId: internalTransactionId });

    // Idempotency Check: If provider request was ALREADY sent and status is already resolved/pending
    if (transaction.providerRequestSent && ['SUCCESS', 'FAILED', 'PENDING'].includes(transaction.status)) {
      console.log(`[RAZORPAY RECHARGE VERIFICATION IDEMPOTENT] Transaction ${internalTransactionId} already dispatched with status ${transaction.status}`);
      return res.status(200).json({
        success: transaction.status !== 'FAILED',
        message: `Payment already verified and recharge status is ${transaction.status}`,
        data: {
          transactionId: transaction.orderId,
          referenceId: transaction.orderId,
          operatorRef: transaction.operatorReference || transaction.providerTransactionId || 'N/A',
          status: transaction.status.toLowerCase(),
          amountPaise: Math.round(transaction.amount * 100),
          commissionAmountPaise: Math.round(transaction.commissionAmount * 100),
          payableAmountPaise: Math.round(transaction.payableAmount * 100),
          mobileNumber: transaction.mobileNumber,
          operatorName: transaction.internalOperatorName || 'Operator',
          timestamp: transaction.completedAt || transaction.updatedAt,
          isDuplicate: true,
        },
      });
    }

    // Cryptographic Signature Verification
    const expectedSignature = crypto
      .createHmac('sha256', (process.env.RAZORPAY_KEY_SECRET || '').trim())
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    const isValidSignature = expectedSignature === razorpaySignature.trim();
    if (!isValidSignature && process.env.NODE_ENV === 'production') {
      transaction.status = 'FAILED';
      transaction.failureReason = 'Razorpay payment signature verification failed (Tampered payment)';
      await transaction.save();
      if (globalTransaction) {
        globalTransaction.status = 'failed';
        globalTransaction.failureReason = transaction.failureReason;
        await globalTransaction.save();
      }
      return res.status(400).json({
        success: false,
        code: 'INVALID_SIGNATURE',
        message: 'Razorpay payment signature verification failed.',
      });
    }

    // Save Razorpay Payment ID & Signature
    transaction.razorpayPaymentId = razorpayPaymentId;
    transaction.razorpaySignature = razorpaySignature;
    await transaction.save();

    if (globalTransaction) {
      globalTransaction.razorpayPaymentId = razorpayPaymentId;
      await globalTransaction.save();
    }

    // Now execute A1Topup recharge via Central Unified Execution Engine
    const providerResponse = await dispatchA1TopupRecharge({ transaction, globalTransaction, userId });

    const statusLower = (providerResponse.status || transaction.status).toLowerCase();
    const isSuccess = statusLower === 'success' || statusLower === 'pending';

    return res.status(200).json({
      success: isSuccess,
      message: isSuccess ? 'Recharge executed successfully' : (transaction.failureReason || 'Recharge failed at operator'),
      data: {
        transactionId: transaction.orderId,
        referenceId: transaction.orderId,
        operatorRef: providerResponse.operatorReference || providerResponse.providerTransactionId || 'N/A',
        status: statusLower,
        amountPaise: Math.round(transaction.amount * 100),
        commissionAmountPaise: Math.round(transaction.commissionAmount * 100),
        payableAmountPaise: Math.round(transaction.payableAmount * 100),
        mobileNumber: transaction.mobileNumber,
        operatorName: transaction.internalOperatorName || 'Operator',
        timestamp: transaction.completedAt || new Date(),
        failureReason: transaction.failureReason || null,
      },
    });
  } catch (error) {
    console.error('[RAZORPAY VERIFY & RECHARGE ERROR]:', error);
    next(error);
  }
};

// @desc    Execute a recharge transaction
// @route   POST /api/recharge/mobile
// @access  Private (Retailer)
const executeRecharge = async (req, res, next) => {
  console.log(`[${new Date().toISOString()}] [2] CONTROLLER ENTERED: executeRecharge`);
  let orderId = `A1R${Date.now()}${Math.floor(Math.random() * 1000)}`;
  let amountForRollback = 0;
  let walletReserved = false;
  let transaction;
  let globalTransaction;

  // Compatibility Layer for Flutter payload (accept mobileNumber, phoneNumber, or subscriberNumber)
  let mobileNumber = req.body.mobileNumber || req.body.phoneNumber || req.body.subscriberNumber || 'N/A';
  let {
    amount,
    operatorId,
    circleId,
    amountPaise,
    mpin,
    paymentMode = 'wallet',
    planId,
    planName,
    planType,
    selectedCategory,
    providerOperatorCode: reqProviderOpCode,
  } = req.body;
  const userId = req.user._id;

  // Convert amountPaise to amount (INR) if provided
  if (amountPaise && !amount) {
    amount = amountPaise / 100;
  }
  amount = amount || 0;

  try {
    // Requirement 1: Create transaction record immediately in INITIATED status
    transaction = await RechargeTransaction.create({
      orderId,
      clientOrderId: orderId,
      userId,
      providerName: 'A1Topup',
      mobileNumber,
      amount,
      operatorCode: operatorId || 'UNKNOWN',
      circleCode: circleId || '4',
      status: 'INITIATED',
      reservedAmount: 0,
      operatorId: operatorId || null,
      serviceType: req.body.serviceType || 'mobile',
      planId: planId || null,
      planName: planName || null,
      planType: planType || null,
      internalOperatorId: operatorId || null,
      internalOperatorName: req.body.operatorName || null,
    });

    globalTransaction = await Transaction.create({
      userId,
      type: 'debit',
      amountPaise: amount * 100,
      status: 'initiated',
      service: req.body.serviceType || 'mobile_recharge',
      referenceId: orderId,
      description: `Recharge for ${mobileNumber}`,
      recipientName: mobileNumber,
      mobileNumber: mobileNumber,
      operatorName: operatorId || 'Operator',
      operatorId: operatorId || null,
      paymentMethod: paymentMode,
    });

    console.log(`[TXN CREATED] orderId=${orderId}, status=INITIATED, mobile=${mobileNumber}, amount=${amount}`);

    // Helper to handle validation / pre-check failures
    const handlePreCheckFailure = async (step, errorMsg, statusCode = 400, details = null) => {
      console.log(`\n====================================================`);
      console.log(`[RECHARGE VALIDATION FAILURE]`);
      console.log(`- Step / Validation Name: ${step}`);
      console.log(`- Input Values:`, details || { mobileNumber, amount, amountPaise, operatorId, circleId, paymentMode, mpin: mpin ? '******' : 'MISSING' });
      console.log(`- Failure Reason: ${errorMsg}`);
      console.log(`====================================================\n`);

      if (transaction) {
        transaction.status = 'FAILED';
        transaction.failureReason = errorMsg;
        transaction.completedAt = new Date();
        await transaction.save().catch(e => console.error(e));
      }

      if (globalTransaction) {
        globalTransaction.status = 'failed';
        globalTransaction.failureReason = errorMsg;
        globalTransaction.completedAt = new Date();
        await globalTransaction.save().catch(e => console.error(e));
      }

      if (walletReserved) {
        await walletService.releaseReservation(userId, amountForRollback).catch(e => console.error('Release reservation error:', e));
        walletReserved = false;
      }

      notificationService.sendRechargeFailed({
        userId,
        transactionId: orderId,
        orderId,
        operator: String(operatorId || 'Operator'),
        amount,
        number: mobileNumber,
        reason: errorMsg,
      });

      return res.status(statusCode).json({
        success: false,
        code: step === "MPIN Validation" ? "INVALID_MPIN" : (step === "Payload Validation" ? "INVALID_PAYLOAD" : "RECHARGE_FAILED"),
        message: errorMsg,
        error: errorMsg,
        reason: errorMsg,
        failureReason: errorMsg,
        step,
        details,
        data: {
          transactionId: orderId,
          referenceId: orderId,
          operatorRef: 'N/A',
          status: 'failed',
          amountPaise: amount * 100,
          mobileNumber: mobileNumber,
          operatorName: String(operatorId || 'Operator').toUpperCase(),
          timestamp: transaction ? transaction.createdAt : new Date(),
          failureReason: errorMsg,
        }
      });
    };

    // Step 3: BEFORE payload validation
    console.log(`[${new Date().toISOString()}] [3] BEFORE payload validation:`, { mobileNumber, amount, amountPaise, operatorId, serviceType: req.body.serviceType });

    if (!mobileNumber || mobileNumber === 'N/A' || !amount || amount <= 0 || !operatorId) {
      return await handlePreCheckFailure("Payload Validation", "Missing or invalid required fields", 400, { mobileNumber, amount, operatorId });
    }

    // Step 4: AFTER payload validation
    console.log(`[${new Date().toISOString()}] [4] AFTER payload validation: PASS`);

    // Wallet MPIN Validation (Required ONLY if paymentMode is wallet)
    if (String(paymentMode || 'wallet').toLowerCase() === 'wallet') {
      const inputMpin = req.body.walletMpin || mpin;
      if (!inputMpin) {
        return await handlePreCheckFailure("MPIN Validation", "Missing Wallet MPIN", 400);
      }
      const isMatch = await req.user.matchMpin(inputMpin);
      if (!isMatch) {
        return await handlePreCheckFailure("MPIN Validation", "Invalid Wallet MPIN", 400);
      }
    }

    // Step 5: AFTER MPIN validation
    console.log(`[${new Date().toISOString()}] [5] AFTER MPIN validation: PASS`);

    // Resolve Provider Mapping
    let operator;
    if (mongoose.Types.ObjectId.isValid(operatorId)) {
      operator = await ProviderOperator.findById(operatorId);
    }

    if (!operator) {
      const codeLookup = String(operatorId || '').toUpperCase().trim();
      operator = await ProviderOperator.findOne({ code: codeLookup, provider: 'A1Topup' });
    }

    if (!operator) {
      const slug = String(operatorId || '').toLowerCase().trim();
      const legacyMap = {
        'jio': 'RC', 'reliance jio': 'RC', 'jio-topup': 'RC', 'jio_topup': 'RC', 'jio topup': 'RC',
        'airtel': 'A', 'airtel-topup': 'A', 'airtel_topup': 'A', 'airtel topup': 'A',
        'vi': 'V', 'vodafone': 'V', 'idea': 'V', 'vi-topup': 'V', 'vi_topup': 'V', 'vi topup': 'V',
        'bsnl': 'BT', 'bsnl-topup': 'BT', 'bsnl topup': 'BT', 'bsnl_topup': 'BT', 'bsnl-special': 'BR', 'bsnl special': 'BR',
        'dth_tata': 'TTV', 'tata sky': 'TTV', 'tatasky': 'TTV',
        'dth_airtel': 'ATV', 'airtel dth': 'ATV',
        'dth_dish': 'DTV', 'dish tv': 'DTV',
        'sun direct': 'STV', 'dth_sun': 'STV',
        'videocon': 'd2h', 'd2h': 'd2h', 'dth_d2h': 'd2h'
      };
      const mappedCode = legacyMap[slug];
      if (mappedCode) {
        operator = await ProviderOperator.findOne({ code: mappedCode, provider: 'A1Topup' });
      }
    }

    if (!operator && req.body.operatorName) {
      const firstWord = String(req.body.operatorName).trim().split(' ')[0];
      operator = await ProviderOperator.findOne({ name: new RegExp(firstWord, 'i'), provider: 'A1Topup' });
    }

    if (!operator || !operator.status) {
      return await handlePreCheckFailure("Operator Validation", `Invalid or disabled operator ID '${operatorId}'`, 400, { operatorId });
    }

    // Update names now that operator is resolved
    globalTransaction.operatorName = req.body.operatorName || operator.name;
    globalTransaction.description = `Recharge for ${mobileNumber} - ${globalTransaction.operatorName}`;
    await globalTransaction.save();

    // Step 7: AFTER operator lookup
    console.log(`[${new Date().toISOString()}] [7] AFTER operator lookup: PASS`, { name: operator.name, code: operator.code, serviceType: operator.serviceType });

    let circle;
    if (circleId && mongoose.Types.ObjectId.isValid(circleId)) {
      circle = await ProviderCircle.findById(circleId);
    } else {
      circle = await ProviderCircle.findOne({ code: '4', provider: 'A1Topup' });
      if (!circle) circle = await ProviderCircle.findOne({ status: true });
    }

    let operatorCode = operator.code;
    const circleCode = circle ? circle.code : '4';

    const isDthService = (operator.serviceType && operator.serviceType.toUpperCase() === 'DTH') ||
      ['dth_tata', 'dth_airtel', 'dth_dish', 'dth_videocon', 'dth_sun'].includes(String(operatorId).toLowerCase()) ||
      req.body.serviceType === 'dth';

    const transactionService = isDthService ? 'dth' : (req.body.serviceType || 'mobile_recharge');

    if (isDthService) {
      const dthMappingService = require('../services/dthMapping.service');
      try {
        operatorCode = dthMappingService.getA1DthOperatorCode(operator);
      } catch (mapErr) {
        return await handlePreCheckFailure("DTH Operator Mapping", mapErr.message, 400, { operatorId, operatorName: operator.name });
      }
    }

    // Step 8: Centralized Operator & Plan Type Provider Code Resolution
    const providerOperatorCode = resolveProviderOperatorCode({
      operator,
      operatorId,
      operatorName: req.body.operatorName,
      planType,
      selectedCategory,
      planName,
      providerOperatorCode: reqProviderOpCode,
    });

    if (!isDthService) {
      operatorCode = providerOperatorCode;
    }

    // TASK 10 — PREVENT REGRESSION VALIDATION
    const isBsnl = isBsnlOperator(operator?.name, operatorId, operatorCode);
    const normPlanType = String(planType || '').toUpperCase().trim();
    if (isBsnl) {
      if ((normPlanType === 'STV' || reqProviderOpCode === 'BR') && providerOperatorCode !== 'BR') {
        return await handlePreCheckFailure(
          "Operator Code Validation",
          `Invalid provider operator code for BSNL STV. Expected BR but got ${providerOperatorCode}`,
          400,
          { selectedPlanType: planType, providerOperatorCode }
        );
      }
      if ((normPlanType === 'TOPUP' || reqProviderOpCode === 'BT') && providerOperatorCode !== 'BT') {
        return await handlePreCheckFailure(
          "Operator Code Validation",
          `Invalid provider operator code for BSNL TOPUP. Expected BT but got ${providerOperatorCode}`,
          400,
          { selectedPlanType: planType, providerOperatorCode }
        );
      }
    }

    // Server-side calculation of commission and net payable amount
    const payableDetails = await calculateRechargePayableHelper({
      serviceType: transactionService,
      operatorCode,
      operatorName: operator ? operator.name : (req.body.operatorName || ''),
      amount,
      userId,
      planType,
      accountType: req.user?.accountType || 'BUSINESS',
    });

    const commissionAmount = payableDetails.commissionAmount;
    const payableAmount = payableDetails.payableAmount; // e.g., 98 for 100 recharge

    transaction.accountType = payableDetails.accountType;
    transaction.commissionRecordId = payableDetails.commissionRecordId;
    transaction.commissionPercent = payableDetails.commissionPercentage;
    transaction.commissionAmount = commissionAmount;
    transaction.payableAmount = payableAmount;
    transaction.reservedAmount = payableAmount;
    await transaction.save();

    if (globalTransaction) {
      globalTransaction.accountType = payableDetails.accountType;
      globalTransaction.commissionRecordId = payableDetails.commissionRecordId;
      globalTransaction.payableAmountPaise = Math.round(payableAmount * 100);
      globalTransaction.commissionEarnedPaise = Math.round(commissionAmount * 100);
      await globalTransaction.save();
    }

    const isWalletPayment = String(paymentMode || 'wallet').toLowerCase() === 'wallet';

    if (isWalletPayment) {
      amountForRollback = payableAmount;
      try {
        await walletService.reserveAmount(userId, payableAmount);
        walletReserved = true;

        notificationService.notifyWalletDebit({
          userId,
          amount,
          payableAmount,
          reason: `Recharge for ${mobileNumber}`,
          referenceId: orderId
        });
      } catch (resErr) {
        return await handlePreCheckFailure("Wallet Reservation", resErr.message, 400);
      }
    } else {
      console.log(`[RECHARGE PAYMENT] paymentMethod=${paymentMode.toUpperCase()} — Skipping wallet balance validation & wallet reservation.`);
    }

    // Step 6: AFTER wallet reservation
    console.log(`[${new Date().toISOString()}] [6] AFTER wallet reservation: PASS (amount=${amount}, payableAmount=${payableAmount})`);
    transaction.operatorCode = operatorCode;
    transaction.circleCode = circleCode;
    transaction.providerOperatorCode = providerOperatorCode;
    transaction.planId = planId || null;
    transaction.planName = planName || null;
    transaction.planType = planType || null;
    transaction.internalOperatorId = operatorId || null;
    transaction.internalOperatorName = operator ? operator.name : (req.body.operatorName || null);
    await transaction.save();

    globalTransaction.status = 'pending';
    globalTransaction.service = transactionService;
    await globalTransaction.save();

    // Call Central Unified A1Topup Execution Engine
    const providerResponse = await dispatchA1TopupRecharge({ transaction, globalTransaction, userId });

    const statusLower = transaction.status.toLowerCase();
    const isSuccess = statusLower === 'success';
    const isPending = statusLower === 'pending';

    return res.status(200).json({
      success: isSuccess || isPending,
      message: isSuccess
        ? 'Recharge executed successfully'
        : (isPending ? 'Recharge is currently processing' : (transaction.failureReason || 'Recharge failed at operator')),
      data: {
        transactionId: transaction.orderId,
        referenceId: transaction.orderId,
        operatorRef: providerResponse.operatorReference || providerResponse.providerTransactionId || 'N/A',
        status: statusLower,
        amountPaise: Math.round(transaction.amount * 100),
        commissionAmountPaise: Math.round(transaction.commissionAmount * 100),
        payableAmountPaise: Math.round(transaction.payableAmount * 100),
        mobileNumber: transaction.mobileNumber,
        operatorName: transaction.internalOperatorName || 'Operator',
        timestamp: transaction.completedAt || new Date(),
        failureReason: transaction.failureReason || null,
      },
    });

  } catch (error) {
    console.error("STEP ERROR: Catch Block in executeRecharge", error);
    const errorMsg = error.message || 'Internal server error';

    // GUARD: If transaction is already SUCCESS or PENDING, NEVER mark it as FAILED!
    if (transaction && (transaction.status === 'SUCCESS' || transaction.status === 'PENDING')) {
      console.warn(`[RECHARGE CATCH GUARD] Transaction ${orderId} is already ${transaction.status}. Suppressing failure fallback.`);
      const statusLower = transaction.status.toLowerCase();
      return res.status(200).json({
        success: true,
        message: statusLower === 'success' ? 'Recharge successful' : 'Recharge pending verification',
        data: {
          transactionId: transaction.orderId,
          referenceId: transaction.orderId,
          operatorRef: transaction.operatorReference || transaction.providerTransactionId || 'Processing...',
          status: statusLower,
          amountPaise: (transaction.amount || 0) * 100,
          mobileNumber: transaction.mobileNumber,
          operatorName: String(transaction.internalOperatorName || 'OPERATOR').toUpperCase(),
          timestamp: transaction.createdAt,
        }
      });
    }

    if (transaction && typeof transaction.save === 'function') {
      transaction.status = 'FAILED';
      transaction.failureReason = errorMsg;
      transaction.completedAt = new Date();
      try { await transaction.save(); } catch (e) { console.error(e); }
    }

    if (globalTransaction && typeof globalTransaction.save === 'function') {
      globalTransaction.status = 'failed';
      globalTransaction.failureReason = errorMsg;
      globalTransaction.completedAt = new Date();
      try { await globalTransaction.save(); } catch (e) { console.error(e); }
    }

    if (walletReserved) {
      try { await walletService.releaseReservation(req.user._id, amountForRollback); } catch (e) { console.error(e); }
      walletReserved = false;
    }

    console.log(`[TXN UPDATED FAILED] orderId=${orderId}, failureReason=${errorMsg}`);

    return res.status(400).json({
      success: false,
      code: "RECHARGE_FAILED",
      message: errorMsg,
      error: errorMsg,
      step: "Exception Catch Block",
      details: error.stack,
      data: {
        transactionId: orderId,
        referenceId: orderId,
        operatorRef: 'N/A',
        status: 'failed',
        amountPaise: (amount || 0) * 100,
        mobileNumber: mobileNumber,
        operatorName: 'OPERATOR',
        timestamp: transaction ? transaction.createdAt : new Date(),
        failureReason: errorMsg,
      }
    });
  }
};

// @desc    Check status of a recharge transaction
// @route   GET /api/recharge/status/:orderId
// @access  Private
const checkStatus = async (req, res, next) => {
  try {
    const { orderId } = req.params;
    const userId = req.user._id;

    // Admin can check any status, Retailer can only check their own
    const query = { orderId };
    if (req.user.role !== 'admin') {
      query.userId = userId;
    }

    const transaction = await RechargeTransaction.findOne(query);

    if (!transaction) {
      res.status(404);
      throw new Error('Transaction not found');
    }

    if (!transaction.providerTransactionId && !transaction.orderId) {
      res.status(400);
      throw new Error('No valid transaction ID associated with this order.');
    }

    if (!transaction.providerRequestSent && (transaction.paymentMethod === 'RAZORPAY_UPI' || transaction.paymentMethod === 'RAZORPAY' || transaction.razorpayPaymentId)) {
      console.log(`[STATUS CHECK RECOVERY] Executing missing A1Topup recharge for order ${transaction.orderId}`);
      const providerResp = await dispatchA1TopupRecharge({
        transaction,
        globalTransaction: await Transaction.findOne({ referenceId: orderId }),
        userId: transaction.userId,
      });

      return res.status(200).json({
        success: providerResp.status !== 'FAILED',
        data: {
          status: providerResp.status,
          orderId: transaction.orderId,
          internalOperator: transaction.internalOperatorName || transaction.operatorId,
          providerOperatorCode: transaction.providerOperatorCode || transaction.operatorCode,
          planType: transaction.planType || 'N/A',
          amount: transaction.amount,
          circle: transaction.circleCode,
          providerTransactionId: providerResp.providerTransactionId || transaction.providerTransactionId,
          message: providerResp.message || 'Status retrieved',
        },
      });
    }

    const statusResponse = await a1TopupProvider.status(transaction.orderId);

    // If status changed to SUCCESS from PENDING, we must run commission/ledger logic
    if (transaction.status === 'PENDING' && statusResponse.status === 'SUCCESS') {
      const now = new Date();
      const updated = await RechargeTransaction.findOneAndUpdate(
        { _id: transaction._id, status: 'PENDING' },
        { $set: { status: 'SUCCESS', providerStatus: 'SUCCESS', operatorReference: statusResponse.operatorReference, providerTransactionId: statusResponse.providerTransactionId || transaction.providerTransactionId, completedAt: now } }
      );
      if (!updated) {
        return res.status(200).json({ success: true, data: statusResponse }); // Already handled
      }

      // Deduct Wallet ONLY IF WALLET PAYMENT
      if (transaction.paymentMethod === 'WALLET' || transaction.paymentMethod === 'wallet') {
        await walletService.commitReservation(transaction.userId, transaction.payableAmount || transaction.amount).catch(() => {});
        await ledgerService.logTransaction({
          userId: transaction.userId,
          type: 'DEBIT',
          amount: transaction.payableAmount || transaction.amount,
          referenceType: 'RECHARGE',
          referenceId: transaction._id,
          description: `Recharge for ${transaction.mobileNumber} - Order ID: ${transaction.orderId}`,
        }).catch(() => {});
      }

      // Calculate & Credit Commission safely and idempotently
      await processSuccessCommission({
        transaction,
        globalTransaction: null,
        userId: transaction.userId,
        orderId: transaction.orderId,
        mobileNumber: transaction.mobileNumber,
        operator: { name: transaction.internalOperatorName || transaction.operatorName },
        operatorCode: transaction.providerOperatorCode || transaction.operatorCode,
        amount: transaction.amount,
        planType: transaction.planType,
        serviceType: 'mobile',
      });

      notificationService.sendRechargeSuccess({
        userId: transaction.userId,
        transactionId: statusResponse.providerTransactionId || transaction.orderId,
        orderId: transaction.orderId,
        amount: transaction.amount,
        number: transaction.mobileNumber,
        isUpdateFromPending: true,
      });

    } else if (transaction.status === 'PENDING' && statusResponse.status === 'FAILED') {
      const now = new Date();
      const updated = await RechargeTransaction.findOneAndUpdate(
        { _id: transaction._id, status: 'PENDING' },
        { $set: { status: 'FAILED', providerStatus: 'FAILED', failureReason: statusResponse.message, completedAt: now } }
      );
      if (!updated) {
        return res.status(200).json({ success: true, data: statusResponse }); // Already handled
      }

      if (transaction.paymentMethod === 'WALLET' || transaction.paymentMethod === 'wallet') {
        try {
          await walletService.releaseReservation(transaction.userId, transaction.payableAmount || transaction.amount);
        } catch (walletError) {
          console.error(`[checkStatus] Critical Wallet Error for ${transaction.orderId}:`, walletError.message);
        }
      } else if (transaction.razorpayPaymentId) {
        try {
          const razorpay = getRazorpayInstance();
          const payablePaise = Math.round((transaction.payableAmount || transaction.amount) * 100);
          await razorpay.payments.refund(transaction.razorpayPaymentId, {
            amount: payablePaise,
            notes: { reason: 'Recharge failed at provider (status check)', orderId: transaction.orderId },
          });
        } catch (rfErr) {
          console.error(`[checkStatus Razorpay Refund Error] ${transaction.razorpayPaymentId}:`, rfErr.message);
        }
      }

      await Transaction.updateOne({ referenceId: transaction.orderId }, {
        status: 'failed',
        apiReference: statusResponse.providerTransactionId || transaction.providerTransactionId,
        completedAt: now,
      });

      notificationService.sendRechargeFailed({
        userId: transaction.userId,
        transactionId: statusResponse.providerTransactionId || transaction.orderId,
        orderId: transaction.orderId,
        amount: transaction.amount,
        number: transaction.mobileNumber,
        reason: statusResponse.message || 'Operator rejected the recharge.',
      });
    }

    res.status(200).json({
      success: true,
      data: {
        ...statusResponse,
        orderId: transaction.orderId,
        internalOperator: transaction.internalOperatorName || transaction.operatorId,
        providerOperatorCode: transaction.providerOperatorCode || transaction.operatorCode,
        planType: transaction.planType || 'N/A',
        amount: transaction.amount,
        circle: transaction.circleCode,
        providerTransactionId: statusResponse.providerTransactionId || transaction.providerTransactionId,
        providerStatus: statusResponse.status || transaction.status,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Handle asynchronous callback/webhook from provider
// @route   POST /api/recharge/callback
// @access  Public (Provider)
const providerCallback = async (req, res, next) => {
  try {
    // Assuming A1 Topup sends: { txnid, status, opid, message, client_id }
    // Providers sometimes use GET instead of POST for webhooks, so check both body and query
    const data = Object.keys(req.body).length > 0 ? req.body : req.query;

    const { txid, txnid, status, opid, message, orderid, client_id } = data;

    const actualTxId = txid || txnid;
    const actualOrderId = orderid || client_id;

    if (!actualTxId && !actualOrderId) {
      return res.status(400).send('Invalid payload');
    }

    // Find transaction by orderId (actualOrderId) or providerTransactionId (actualTxId)
    const query = {};
    if (actualOrderId) query.orderId = actualOrderId;
    else if (actualTxId) query.providerTransactionId = actualTxId;

    const transaction = await RechargeTransaction.findOne(query);

    if (!transaction) {
      return res.status(404).send('Transaction not found');
    }

    // If transaction is already processed, return success (Idempotent)
    if (transaction.status === 'SUCCESS' || transaction.status === 'FAILED') {
      return res.status(200).send('OK');
    }

    let normalizedStatus = 'PENDING';
    const rawStatus = (status || '').toUpperCase();
    if (rawStatus === 'SUCCESS' || rawStatus === 'COMPLETED') normalizedStatus = 'SUCCESS';
    else if (rawStatus === 'FAILED' || rawStatus === 'ERROR' || rawStatus === 'FAILURE') normalizedStatus = 'FAILED';

    if (normalizedStatus === 'SUCCESS') {
      const updated = await RechargeTransaction.findOneAndUpdate(
        { _id: transaction._id, status: 'PENDING' },
        { $set: { status: 'SUCCESS', operatorReference: opid || transaction.operatorReference } }
      );
      if (!updated) return res.status(200).send('OK');

      await walletService.commitReservation(transaction.userId, transaction.amount);
      await ledgerService.logTransaction({
        userId: transaction.userId,
        type: 'DEBIT',
        amount: transaction.amount,
        referenceType: 'RECHARGE',
        referenceId: transaction._id,
        description: `Recharge for ${transaction.mobileNumber} - Order ID: ${transaction.orderId}`,
      });

      const commission = await commissionService.calculateCommission(transaction.operatorCode, transaction.amount);
      if (commission.retailerCommissionAmount > 0) {
        await walletService.addBalance(transaction.userId, commission.retailerCommissionAmount);
        await ledgerService.logTransaction({
          userId: transaction.userId,
          type: 'CREDIT',
          amount: commission.retailerCommissionAmount,
          referenceType: 'COMMISSION',
          referenceId: transaction._id,
          description: `Commission for Recharge ${transaction.orderId}`,
        });

        await Transaction.create({
          userId: transaction.userId,
          type: 'credit',
          amountPaise: commission.retailerCommissionAmount * 100,
          status: 'success',
          service: 'commission',
          referenceId: `COM${Date.now()}${Math.floor(Math.random() * 1000)}`,
          description: `Commission for Recharge ${transaction.orderId}`,
          apiReference: transaction._id.toString(),
          paymentMethod: 'wallet',
        });
      }

      await Transaction.updateOne({ referenceId: transaction.orderId }, {
        status: 'success',
        apiReference: actualTxId,
        commissionEarnedPaise: commission.retailerCommissionAmount * 100
      });

      await CommissionHistory.create({
        transactionId: transaction._id,
        userId: transaction.userId,
        operatorCode: transaction.operatorCode,
        rechargeAmount: transaction.amount,
        providerCommissionPercentage: commission.providerCommissionPercentage,
        providerCommissionAmount: commission.providerCommissionAmount,
        retailerCommissionPercentage: commission.retailerCommissionPercentage,
        retailerCommissionAmount: commission.retailerCommissionAmount,
        companyProfitPercentage: commission.companyProfitPercentage,
        companyProfitAmount: commission.companyProfitAmount,
      });
      await RechargeTransaction.updateOne({ _id: transaction._id }, { commissionCalculated: true });

      notificationService.sendRechargeSuccess({
        userId: transaction.userId,
        transactionId: actualTxId || transaction.orderId,
        orderId: transaction.orderId,
        amount: transaction.amount,
        number: transaction.mobileNumber,
        isUpdateFromPending: true,
      });
    } else if (normalizedStatus === 'FAILED') {
      const updated = await RechargeTransaction.findOneAndUpdate(
        { _id: transaction._id, status: 'PENDING' },
        { $set: { status: 'FAILED', failureReason: message || 'Failed at provider end' } }
      );
      if (!updated) return res.status(200).send('OK');

      try {
        await walletService.releaseReservation(transaction.userId, transaction.amount);
      } catch (walletError) {
        console.error(`[Webhook] Critical Wallet Error for ${transaction.orderId}:`, walletError.message);
      }

      await Transaction.updateOne({ referenceId: transaction.orderId }, {
        status: 'failed',
        apiReference: actualTxId
      });

      notificationService.sendRechargeFailed({
        userId: transaction.userId,
        transactionId: actualTxId || transaction.orderId,
        orderId: transaction.orderId,
        amount: transaction.amount,
        number: transaction.mobileNumber,
        reason: message || 'Operator rejected the recharge.',
      });
    }
    res.status(200).send('OK'); // Must return 200 OK so provider stops retrying

  } catch (error) {
    console.error('Webhook Error:', error.message);
    res.status(500).send('Internal Server Error');
  }
};

module.exports = {
  checkProviderHealth,
  checkProviderBalance,
  getOperators,
  getPlans,
  calculateRechargePayableHelper,
  calculateRechargePayable,
  createRazorpayRechargeOrder,
  verifyRazorpayRechargePayment,
  dispatchA1TopupRecharge,
  executeRecharge,
  checkStatus,
  providerCallback,
};
