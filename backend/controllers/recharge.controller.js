const a1TopupProvider = require('../services/providers/a1topup/provider.service');
const fast2smsService = require('../services/fast2sms.service');
const notificationService = require('../services/notification.service');
const { resolveProviderOperatorCode, isBsnlOperator } = require('../utils/operatorMapper');

const ProviderWallet = require('../models/ProviderWallet');
const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
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
/**
 * Process retailer commission and record CommissionHistory safely and idempotently
 */
const processSuccessCommission = async ({ transaction, globalTransaction, userId, orderId, mobileNumber, operator, operatorCode, amount, planType, serviceType = 'mobile' }) => {
  try {
    // Step 9: Prevent Duplicate Commission (Idempotency Guard)
    if (transaction.commissionCalculated) {
      console.log(`[COMMISSION IDEMPOTENT] Commission already processed for orderId ${orderId}. Skipping duplicate credit.`);
      return;
    }

    const existingHist = await CommissionHistory.findOne({ transactionId: transaction._id }).catch(() => null);
    if (existingHist) {
      transaction.commissionCalculated = true;
      await transaction.save().catch(() => {});
      console.log(`[COMMISSION IDEMPOTENT] CommissionHistory record already exists for orderId ${orderId}. Skipping duplicate credit.`);
      return;
    }

    // Step 3 & 4: Commission Lookup & Calculation
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

    let ledgerEntryId = 'N/A';

    // Step 6: Credit Retailer Commission
    if (retailerCommissionAmount > 0) {
      const walletBefore = await walletService.getWalletBalance(userId);
      await walletService.addBalance(userId, retailerCommissionAmount);
      const walletAfter = await walletService.getWalletBalance(userId);

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

      await Transaction.create({
        userId,
        type: 'credit',
        amountPaise: Math.round(retailerCommissionAmount * 100),
        status: 'success',
        service: 'commission',
        referenceId: `COM${Date.now()}${Math.floor(Math.random() * 1000)}`,
        description: `Commission for Recharge ${orderId}`,
        apiReference: transaction._id.toString(),
        paymentMethod: 'wallet',
        operatorName: operator ? operator.name : (transaction.internalOperatorName || 'Operator'),
      }).catch(e => console.error('[Global Transaction Commission Warning]:', e.message));

      console.log('\n====================================================');
      console.log('[COMMISSION CREDIT]');
      console.log(`orderId: ${orderId}`);
      console.log(`retailerId: ${userId}`);
      console.log(`rechargeAmount: ${amount}`);
      console.log(`retailerCommissionPercent: ${retailerCommissionPercent}`);
      console.log(`retailerCommissionAmount: ${retailerCommissionAmount}`);
      console.log(`walletBefore: ${walletBefore}`);
      console.log(`walletAfter: ${walletAfter}`);
      console.log(`ledgerEntryId: ${ledgerEntryId}`);
      console.log('====================================================\n');
    }

    // Step 7: Commission History Record (strictly finite numbers)
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
    }).catch(e => console.error('[CommissionHistory Save Error (Suppressed)]:', e.message));

    transaction.commissionCalculated = true;
    await transaction.save().catch(() => {});

    if (globalTransaction) {
      globalTransaction.commissionEarnedPaise = Math.round(retailerCommissionAmount * 100);
      await globalTransaction.save().catch(() => {});
    }

    console.log('\n====================================================');
    console.log('[COMMISSION HISTORY]');
    console.log('created successfully');
    console.log('====================================================\n');

  } catch (err) {
    // Step 8: Successful recharge MUST NOT become failed
    console.error(`[COMMISSION PROCESSING ERROR - RECHARGE REMAINS SUCCESS] orderId=${orderId}:`, err.message);
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

    // MPIN Validation (Required if paymentMode is wallet)
    if (paymentMode === 'wallet') {
      if (!mpin) {
        return await handlePreCheckFailure("MPIN Validation", "Missing MPIN", 400);
      }
      const isMatch = await req.user.matchMpin(mpin);
      if (!isMatch) {
        return await handlePreCheckFailure("MPIN Validation", "Invalid MPIN", 400);
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

    amountForRollback = amount;
    try {
      await walletService.reserveAmount(userId, amount);
      walletReserved = true;
    } catch (resErr) {
      return await handlePreCheckFailure("Wallet Reservation", resErr.message, 400);
    }

    // Step 6: AFTER wallet reservation
    console.log(`[${new Date().toISOString()}] [6] AFTER wallet reservation: PASS (amount=${amount})`);

    // Update status to PENDING before sending to provider
    transaction.status = 'PENDING';
    transaction.operatorCode = operatorCode;
    transaction.circleCode = circleCode;
    transaction.reservedAmount = amount;
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

    // TASK 2 — SAFE DEBUG LOGGING (No credentials printed)
    console.log('\n====================================================');
    console.log('[A1TOPUP FINAL REQUEST]');
    console.log(`orderid: ${orderId}`);
    console.log(`number: ${mobileNumber}`);
    console.log(`amount: ${amount}`);
    console.log(`circlecode: ${circleCode}`);
    console.log(`internalOperatorId: ${operatorId || 'N/A'}`);
    console.log(`internalOperatorName: ${operator ? operator.name : (req.body.operatorName || 'N/A')}`);
    console.log(`selectedPlanId: ${planId || 'N/A'}`);
    console.log(`selectedPlanName: ${planName || 'N/A'}`);
    console.log(`selectedPlanType: ${planType || 'N/A'}`);
    console.log(`providerOperatorCode: ${providerOperatorCode}`);
    console.log('====================================================\n');

    // 4. Call Provider
    const providerResponse = await a1TopupProvider.recharge({
      orderId,
      mobileNumber,
      amount,
      operatorCode,
      circleCode,
      serviceType: operator.serviceType,
    });

    console.log(`[9] A1 Response received: status=${providerResponse.status}, msg=${providerResponse.message || 'N/A'}`);

    // 5. Update Transaction with Provider Response
    transaction.providerTransactionId = providerResponse.providerTransactionId || null;
    transaction.operatorReference = providerResponse.operatorReference || null;
    transaction.status = providerResponse.status;
    transaction.providerStatus = providerResponse.status;
    transaction.providerMessage = providerResponse.message || null;
    globalTransaction.providerTransactionId = providerResponse.providerTransactionId || null;
    globalTransaction.providerMessage = providerResponse.message || null;

    if (providerResponse.status === 'SUCCESS' || providerResponse.status === 'FAILED') {
      transaction.completedAt = new Date();
      globalTransaction.completedAt = new Date();
    }
    if (providerResponse.status === 'FAILED') {
      transaction.failureReason = providerResponse.message || 'Recharge failed at provider';
      globalTransaction.failureReason = transaction.failureReason;
    }

    // 6. Handle Success / Failure / Pending
    if (providerResponse.status === 'SUCCESS') {
      // Step A: Immediately commit wallet reservation & mark walletReserved = false
      try {
        await walletService.commitReservation(userId, amount);
      } catch (commitErr) {
        console.error(`[Wallet Commit Warning] orderId=${orderId}:`, commitErr.message);
      }
      walletReserved = false;

      // Step B: Post-success operations (Ledger, Commission, CommissionHistory, Notifications)
      try {
        await ledgerService.logTransaction({
          userId,
          type: 'DEBIT',
          amount,
          referenceType: 'RECHARGE',
          referenceId: transaction._id,
          description: `Recharge for ${mobileNumber} - Order ID: ${orderId}`,
        }).catch(e => console.error('[Ledger Debit Warning]:', e.message));

        await processSuccessCommission({
          transaction,
          globalTransaction,
          userId,
          orderId,
          mobileNumber,
          operator,
          operatorCode,
          amount,
          planType,
          serviceType: transactionService,
        });

        globalTransaction.status = 'success';
        globalTransaction.apiReference = providerResponse.providerTransactionId;
        await globalTransaction.save().catch(e => console.error(e));
      } catch (postProcErr) {
        console.error('[Post-Success Processing Warning]:', postProcErr.message);
      }

      console.log(`[TXN UPDATED SUCCESS] orderId=${orderId}, providerTransactionId=${providerResponse.providerTransactionId}`);

      notificationService.sendRechargeSuccess({
        userId,
        transactionId: providerResponse.providerTransactionId || orderId,
        orderId,
        service: transactionService,
        operator: operator.name || 'Mobile',
        amount,
        number: mobileNumber,
      });

      fast2smsService.sendRechargeSuccessTemplate({
        customerName: req.user.name || req.user.shopName || 'Valued Retailer',
        mobileNumber: mobileNumber,
        amount: amount,
        operator: operator.name || 'Mobile',
        transactionId: providerResponse.providerTransactionId || orderId,
      }).catch(err => console.error('[WHATSAPP RECHARGE NOTIFICATION ERROR]:', err));

    } else if (providerResponse.status === 'FAILED') {
      await walletService.releaseReservation(userId, amount);
      globalTransaction.status = 'failed';
      globalTransaction.apiReference = providerResponse.providerTransactionId;
      await globalTransaction.save();
      walletReserved = false;

      console.log(`[TXN UPDATED FAILED] orderId=${orderId}, failureReason=${transaction.failureReason}`);

      notificationService.sendRechargeFailed({
        userId,
        transactionId: providerResponse.providerTransactionId || orderId,
        orderId,
        operator: operator ? operator.name : 'Mobile',
        amount,
        number: mobileNumber,
        reason: transaction.failureReason,
      });

    } else if (providerResponse.status === 'PENDING') {
      globalTransaction.status = 'pending';
      globalTransaction.apiReference = providerResponse.providerTransactionId;
      await globalTransaction.save();
      walletReserved = false;

      console.log(`[TXN UPDATED PENDING] orderId=${orderId}, providerTransactionId=${providerResponse.providerTransactionId}`);

      notificationService.sendRechargePending({
        userId,
        transactionId: providerResponse.providerTransactionId || orderId,
        orderId,
        operator: operator ? operator.name : 'Mobile',
        amount,
        number: mobileNumber,
      });
      
      const rechargePoller = require('../utils/rechargePoller');
      rechargePoller.startPolling(transaction.orderId);
    }

    await transaction.save();

    const statusLower = transaction.status.toLowerCase();
    const isSuccess = statusLower === 'success';
    const isPending = statusLower === 'pending';

    let commissionEarnedPaise = 0;
    try {
      if (transaction.commissionCalculated) {
        const commHist = await CommissionHistory.findOne({ transactionId: transaction._id }).catch(() => null);
        commissionEarnedPaise = (commHist?.retailerCommissionAmount || 0) * 100;
      }
    } catch (_) {}

    return res.status(200).json({
      success: isSuccess || isPending,
      message: isSuccess 
        ? 'Recharge successful' 
        : (isPending ? 'Recharge pending verification' : (transaction.failureReason || 'Recharge failed')),
      data: {
        transactionId: transaction.orderId,
        referenceId: transaction.orderId,
        operatorRef: transaction.operatorReference || transaction.providerTransactionId || (isPending ? 'Processing...' : 'N/A'),
        status: statusLower, // 'success', 'failed', 'pending'
        amountPaise: transaction.amount * 100,
        commissionEarnedPaise,
        walletDebitedPaise: (isSuccess && paymentMode === 'wallet') ? transaction.amount * 100 : 0,
        walletBalanceAfterPaise: 0,
        mobileNumber: transaction.mobileNumber,
        operatorName: (operator ? operator.name : 'OPERATOR').toUpperCase(),
        timestamp: transaction.createdAt,
        failureReason: transaction.failureReason || null,
        providerMessage: transaction.providerMessage || null,
      }
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
      await walletService.releaseReservation(req.user._id, amountForRollback).catch(e => console.error(e));
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
      
      // Deduct Wallet
      await walletService.commitReservation(transaction.userId, transaction.amount);
      await ledgerService.logTransaction({
        userId: transaction.userId,
        type: 'DEBIT',
        amount: transaction.amount,
        referenceType: 'RECHARGE',
        referenceId: transaction._id,
        description: `Recharge for ${transaction.mobileNumber} - Order ID: ${transaction.orderId}`,
      });

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
      
      try {
        await walletService.releaseReservation(transaction.userId, transaction.amount);
      } catch (walletError) {
        console.error(`[checkStatus] Critical Wallet Error for ${transaction.orderId}:`, walletError.message);
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
  executeRecharge,
  checkStatus,
  providerCallback,
};
