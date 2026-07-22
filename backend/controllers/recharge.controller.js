const a1TopupProvider = require('../services/providers/a1topup/provider.service');

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

// @desc    Execute a recharge transaction
// @route   POST /api/recharge/mobile
// @access  Private (Retailer)
const executeRecharge = async (req, res, next) => {
  console.log(`[${new Date().toISOString()}] [2] CONTROLLER ENTERED: executeRecharge`);
  let orderId;
  let amountForRollback = 0;
  let walletReserved = false;

  try {
    // Compatibility Layer for Flutter payload (accept mobileNumber, phoneNumber, or subscriberNumber)
    let mobileNumber = req.body.mobileNumber || req.body.phoneNumber || req.body.subscriberNumber;
    let { amount, operatorId, circleId, amountPaise, mpin, paymentMode = 'wallet' } = req.body;
    const userId = req.user._id;

    // Convert amountPaise to amount (INR) if provided
    if (amountPaise && !amount) {
      amount = amountPaise / 100;
    }

    // Step 3: BEFORE payload validation
    console.log(`[${new Date().toISOString()}] [3] BEFORE payload validation:`, { mobileNumber, amount, amountPaise, operatorId, serviceType: req.body.serviceType });

    if (!mobileNumber || !amount || !operatorId || amount <= 0) {
      console.log(`\n[${new Date().toISOString()}] EXIT POINT:\nFile: backend/controllers/recharge.controller.js\nFunction: executeRecharge\nLine: 125\nReason: Payload Validation Failed (mobileNumber=${mobileNumber}, amount=${amount}, operatorId=${operatorId})\n`);
      return res.status(400).json({
        step: "Payload Validation",
        error: "Missing or invalid required fields",
        details: { mobileNumber, amount, operatorId }
      });
    }

    // Step 4: AFTER payload validation
    console.log(`[${new Date().toISOString()}] [4] AFTER payload validation: PASS`);

    // MPIN Validation (Required if paymentMode is wallet)
    if (paymentMode === 'wallet') {
      if (!mpin) {
        console.log(`\n[${new Date().toISOString()}] EXIT POINT:\nFile: backend/controllers/recharge.controller.js\nFunction: executeRecharge\nLine: 145\nReason: Missing MPIN\n`);
        return res.status(400).json({
          step: "MPIN Validation",
          error: "Missing MPIN",
          details: null
        });
      }
      const isMatch = await req.user.matchMpin(mpin);
      if (!isMatch) {
        console.log(`\n[${new Date().toISOString()}] EXIT POINT:\nFile: backend/controllers/recharge.controller.js\nFunction: executeRecharge\nLine: 155\nReason: Invalid MPIN\n`);
        return res.status(400).json({
          step: "MPIN Validation",
          error: "Invalid MPIN",
          details: null
        });
      }
    }

    // Step 5: AFTER MPIN validation
    console.log(`[${new Date().toISOString()}] [5] AFTER MPIN validation: PASS`);

    // Resolve Provider Mapping
    let operator;
    if (mongoose.Types.ObjectId.isValid(operatorId)) {
      operator = await ProviderOperator.findById(operatorId);
    } else {
      const legacyMap = { 'jio': 'RC', 'airtel': 'A', 'vi': 'V', 'bsnl': 'BT', 'dth_tata': 'TTV', 'dth_airtel': 'ATV', 'dth_dish': 'DTV' };
      const mappedCode = legacyMap[String(operatorId).toLowerCase()] || 'RC';
      operator = await ProviderOperator.findOne({ code: mappedCode, provider: 'A1Topup' });
    }

    if (!operator || !operator.status) {
      console.log(`\n[${new Date().toISOString()}] EXIT POINT:\nFile: backend/controllers/recharge.controller.js\nFunction: executeRecharge\nLine: 180\nReason: Invalid or disabled operator ID '${operatorId}'\n`);
      return res.status(400).json({
        step: "Operator Validation",
        error: "Invalid or disabled operator",
        details: { operatorId }
      });
    }

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
        console.log(`\n[${new Date().toISOString()}] EXIT POINT:\nFile: backend/services/dthMapping.service.js\nFunction: getA1DthOperatorCode\nLine: 57\nReason: DTH Operator Mapping Error - ${mapErr.message}\n`);
        return res.status(400).json({
          step: "DTH Operator Mapping",
          error: mapErr.message,
          details: { operatorId, operatorName: operator.name, plansInfoCode: operator.plansInfoCode }
        });
      }
    }

    // Step 8: AFTER DTH mapping
    console.log(`[${new Date().toISOString()}] [8] AFTER DTH mapping: PASS`, { isDthService, operatorCode, circleCode });

    // Dynamic BSNL Routing
    if (operator.name.toUpperCase() === 'BSNL') {
      const PlanCache = require('../models/PlanCache');
      const cache = await PlanCache.findOne({ operatorId: operator._id, circleId: circle._id }).sort({ createdAt: -1 });
      if (cache && cache.plans) {
        const plan = cache.plans.find(p => Number(p.amount) === Number(amount));
        if (plan) {
           const category = (plan.category || '').toLowerCase();
           if (category.includes('top up') || category.includes('talktime')) {
             operatorCode = 'BT';
           } else {
             operatorCode = 'BR';
           }
        } else {
           operatorCode = 'BR';
        }
      } else {
         operatorCode = 'BR';
      }
    }

    orderId = `A1R${Date.now()}${Math.floor(Math.random() * 1000)}`;

    amountForRollback = amount;
    try {
      await walletService.reserveAmount(userId, amount);
      walletReserved = true;
    } catch (resErr) {
      console.log(`\n[${new Date().toISOString()}] EXIT POINT:\nFile: backend/controllers/recharge.controller.js\nFunction: executeRecharge\nLine: 272\nReason: Wallet Reservation Error - ${resErr.message}\n`);
      throw resErr;
    }

    // Step 6: AFTER wallet reservation
    console.log(`[${new Date().toISOString()}] [6] AFTER wallet reservation: PASS (amount=${amount})`);

    const transaction = await RechargeTransaction.create({
      orderId,
      userId,
      providerName: 'A1Topup',
      mobileNumber,
      amount,
      operatorCode,
      circleCode,
      status: 'PENDING',
      reservedAmount: amount,
    });

    const globalTransaction = await Transaction.create({
      userId,
      type: 'debit',
      amountPaise: amount * 100,
      status: 'pending',
      service: transactionService,
      referenceId: orderId,
      description: `Recharge for ${mobileNumber} - ${operator.name}`,
      recipientName: mobileNumber,
      mobileNumber: mobileNumber,
      operatorName: operator.name,
      paymentMethod: paymentMode,
    });

    // Step 9: IMMEDIATELY BEFORE calling a1TopupProvider.recharge()
    console.log(`[${new Date().toISOString()}] [9] IMMEDIATELY BEFORE calling a1TopupProvider.recharge()`, {
      orderId,
      mobileNumber,
      amount,
      operatorCode,
      circleCode,
      serviceType: operator.serviceType,
    });

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
    console.log(`A1 Status: ${providerResponse.status}`);
    console.log(`A1 Remark: ${providerResponse.message || 'N/A'}`);

    // 5. Update Transaction with Provider Response
    transaction.providerTransactionId = providerResponse.providerTransactionId;
    transaction.operatorReference = providerResponse.operatorReference;
    transaction.status = providerResponse.status;
    transaction.providerStatus = providerResponse.status;
    if (providerResponse.status === 'SUCCESS' || providerResponse.status === 'FAILED') {
      transaction.completedAt = new Date();
    }
    if (providerResponse.status === 'FAILED') {
      transaction.failureReason = providerResponse.message || 'Recharge failed at provider';
    }

    // 6. Handle Success / Failure / Pending
    if (providerResponse.status === 'SUCCESS') {
      // Deduct Wallet
      await walletService.commitReservation(userId, amount);

      // Ledger Logging for Deduction
      await ledgerService.logTransaction({
        userId,
        type: 'DEBIT',
        amount,
        referenceType: 'RECHARGE',
        referenceId: transaction._id,
        description: `Recharge for ${mobileNumber} - Order ID: ${orderId}`,
      });

      // Calculate & Credit Commission
      const commission = await commissionService.calculateCommission(operatorCode, amount, operator.name);
      if (commission.retailerCommissionAmount > 0) {
        // Credit retailer
        await walletService.addBalance(userId, commission.retailerCommissionAmount);
        await ledgerService.logTransaction({
          userId,
          type: 'CREDIT',
          amount: commission.retailerCommissionAmount,
          referenceType: 'COMMISSION',
          referenceId: transaction._id,
          description: `Commission for Recharge ${orderId}`,
        });
        
        await Transaction.create({
          userId,
          type: 'credit',
          amountPaise: commission.retailerCommissionAmount * 100,
          status: 'success',
          service: 'commission',
          referenceId: `COM${Date.now()}${Math.floor(Math.random() * 1000)}`,
          description: `Commission for Recharge ${orderId}`,
          apiReference: transaction._id.toString(),
          paymentMethod: 'wallet',
          operatorName: operator.name,
        });
      }

      // Record Commission History
      await CommissionHistory.create({
        transactionId: transaction._id,
        userId,
        operatorCode,
        rechargeAmount: amount,
        providerCommissionPercentage: commission.providerCommissionPercentage,
        providerCommissionAmount: commission.providerCommissionAmount,
        retailerCommissionPercentage: commission.retailerCommissionPercentage,
        retailerCommissionAmount: commission.retailerCommissionAmount,
        companyProfitPercentage: commission.companyProfitPercentage,
        companyProfitAmount: commission.companyProfitAmount,
      });

      transaction.commissionCalculated = true;
      globalTransaction.status = 'success';
      globalTransaction.apiReference = providerResponse.providerTransactionId;
      globalTransaction.commissionEarnedPaise = commission.retailerCommissionAmount * 100;
      globalTransaction.completedAt = new Date();
      await globalTransaction.save();
      walletReserved = false;
    } else if (providerResponse.status === 'FAILED') {
      // Immediate Release of Wallet Reservation
      await walletService.releaseReservation(userId, amount);
      globalTransaction.status = 'failed';
      globalTransaction.apiReference = providerResponse.providerTransactionId;
      globalTransaction.completedAt = new Date();
      await globalTransaction.save();
      walletReserved = false;
    } else if (providerResponse.status === 'PENDING') {
      globalTransaction.status = 'pending';
      globalTransaction.apiReference = providerResponse.providerTransactionId;
      await globalTransaction.save();
      walletReserved = false;
      
      const rechargePoller = require('../utils/rechargePoller');
      rechargePoller.startPolling(transaction.orderId);
    }

    await transaction.save();
    console.log(`Database Status After: ${transaction.status}`);
    console.log('--- END RECHARGE LIFECYCLE TRACE ---\n');

    // Return HTTP 200 for all completed states so Flutter can display the receipt with clean status
    const statusLower = transaction.status.toLowerCase();
    const isSuccess = statusLower === 'success';
    const isPending = statusLower === 'pending';

    res.status(200).json({
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
        commissionEarnedPaise: transaction.commissionCalculated ? ((await CommissionHistory.findOne({ transactionId: transaction._id }))?.retailerCommissionAmount || 0) * 100 : 0,
        walletDebitedPaise: (isSuccess && paymentMode === 'wallet') ? transaction.amount * 100 : 0,
        walletBalanceAfterPaise: 0,
        mobileNumber: transaction.mobileNumber,
        operatorName: operator.name.toUpperCase(),
        timestamp: transaction.createdAt,
        failureReason: transaction.failureReason || null,
      }
    });

  } catch (error) {
    if (walletReserved) {
      await walletService.releaseReservation(req.user._id, amountForRollback);
      if (orderId) {
         await Transaction.updateOne({ referenceId: orderId }, { status: 'failed' }).catch(e => console.error(e));
         await RechargeTransaction.updateOne({ orderId }, { status: 'FAILED', failureReason: error.message }).catch(e => console.error(e));
      }
    }
    console.log("STEP ERROR: Catch Block");
    console.log(error);
    
    return res.status(400).json({
       step: "Exception Catch Block",
       error: error.message,
       details: error.stack
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

      // Calculate & Credit Commission
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
          completedAt: now,
        });
      }
      
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

      await Transaction.updateOne({ referenceId: transaction.orderId }, { 
        status: 'success', 
        apiReference: statusResponse.providerTransactionId || transaction.providerTransactionId,
        commissionEarnedPaise: commission.retailerCommissionAmount * 100,
        completedAt: now,
      });

      await RechargeTransaction.updateOne({ _id: transaction._id }, { commissionCalculated: true });
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
    }

    res.status(200).json({
      success: true,
      data: statusResponse,
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
