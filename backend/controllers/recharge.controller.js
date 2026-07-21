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
  let orderId;
  let amountForRollback = 0;
  let walletReserved = false;

  try {
    // Compatibility Layer for Flutter legacy payload
    let { mobileNumber, amount, operatorId, circleId, amountPaise, mpin, paymentMode = 'wallet' } = req.body;
    const userId = req.user._id;

    console.log("STEP 1: Request Payload");
    console.log(req.body);
    console.log("amount =", amount);
    console.log("amountPaise =", amountPaise);

    // Convert amountPaise to amount (INR) if provided
    if (amountPaise && !amount) {
      amount = amountPaise / 100;
    }
    console.log("amount after conversion =", amount);

    if (!mobileNumber || !amount || !operatorId) {
      return res.status(400).json({
        step: "Payload Validation",
        error: "Missing required fields",
        details: { mobileNumber, amount, operatorId }
      });
    }

    if (amount <= 0) {
      return res.status(400).json({
        step: "Amount Validation",
        error: "Invalid amount",
        details: { amount }
      });
    }

    // MPIN Validation (Required if paymentMode is wallet)
    if (paymentMode === 'wallet') {
      if (!mpin) {
        return res.status(400).json({
          step: "MPIN Validation",
          error: "Missing MPIN",
          details: null
        });
      }
      console.log("STEP 2: MPIN Check");
      const isMatch = await req.user.matchMpin(mpin);
      if (!isMatch) {
        return res.status(400).json({
          step: "MPIN Validation",
          error: "Invalid MPIN",
          details: null
        });
      }
    }

    // Resolve Provider Mapping (Compatibility for Flutter string operatorIds)
    let operator;
    if (mongoose.Types.ObjectId.isValid(operatorId)) {
      operator = await ProviderOperator.findById(operatorId);
    } else {
      // Legacy string ID mapping (jio -> RC, airtel -> A, vi -> V, bsnl -> BT)
      const legacyMap = { 'jio': 'RC', 'airtel': 'A', 'vi': 'V', 'bsnl': 'BT', 'dth_tata': 'TTV', 'dth_airtel': 'ATV', 'dth_dish': 'DTV' };
      const mappedCode = legacyMap[operatorId.toLowerCase()] || 'RC';
      operator = await ProviderOperator.findOne({ code: mappedCode, provider: 'A1Topup' });
    }

    console.log("STEP 3: Operator Resolved");
    console.log(operator);

    if (!operator) {
      return res.status(400).json({
        step: "Operator Validation",
        error: "Invalid operator",
        details: { operatorId }
      });
    }
    if (!operator.status) {
      return res.status(400).json({
        step: "Operator Validation",
        error: "Operator is currently disabled",
        details: { operatorId }
      });
    }

    let circle;
    if (circleId && mongoose.Types.ObjectId.isValid(circleId)) {
      circle = await ProviderCircle.findById(circleId);
    } else {
      // Fallback: Default to a valid circle (e.g., Maharashtra - code '4') since Flutter doesn't send it yet
      circle = await ProviderCircle.findOne({ code: '4', provider: 'A1Topup' });
      if (!circle) circle = await ProviderCircle.findOne({ status: true });
    }

    console.log("STEP 4: Circle Resolved");
    console.log(circle);

    if (!circle) {
      return res.status(400).json({
        step: "Circle Validation",
        error: "Invalid circle",
        details: { circleId }
      });
    }
    if (!circle.status) {
      return res.status(400).json({
        step: "Circle Validation",
        error: "Circle is currently disabled",
        details: { circleId }
      });
    }

    let operatorCode = operator.code;
    const circleCode = circle.code;

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
           console.log(`[Recharge] Dynamic BSNL Routing: Amount ${amount} -> Category "${category}" -> Code ${operatorCode}`);
        } else {
           operatorCode = 'BR';
           console.log(`[Recharge] Dynamic BSNL Routing: Amount ${amount} not found in cache -> Defaulting to BR`);
        }
      } else {
         operatorCode = 'BR';
         console.log(`[Recharge] Dynamic BSNL Routing: No cache found -> Defaulting to BR`);
      }
    }

    // 1. Generate Order ID
    orderId = `A1R${Date.now()}${Math.floor(Math.random() * 1000)}`;

    console.log("STEP 5: Wallet Check");
    console.log("Reserving wallet amount:", amount);

    // 2. Reserve Wallet Balance
    amountForRollback = amount;
    await walletService.reserveAmount(userId, amount);
    walletReserved = true;

    // 3. Create Pending Transaction
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
      service: 'mobile_recharge',
      referenceId: orderId,
      description: `Recharge for ${mobileNumber} - ${operator.name}`,
      recipientName: mobileNumber,
      mobileNumber: mobileNumber,
      operatorName: operator.name,
      paymentMethod: paymentMode,
    });

    console.log("======================");
    console.log("A1 REQUEST");
    console.log({
      orderId,
      mobileNumber,
      amount,
      operatorCode,
      circleCode,
    });
    console.log("======================");

    // 4. Call Provider
    const providerResponse = await a1TopupProvider.recharge({
      orderId,
      mobileNumber,
      amount,
      operatorCode,
      circleCode,
    });

    console.log("A1 RESPONSE");
    console.log(providerResponse);

    // 5. Update Transaction with Provider Response
    transaction.providerTransactionId = providerResponse.providerTransactionId;
    transaction.operatorReference = providerResponse.operatorReference;
    transaction.status = providerResponse.status;
    if (providerResponse.status === 'FAILED') {
      transaction.failureReason = providerResponse.message;
    }

    // 6. Handle Success / Failure
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
        await walletService.addBalance(userId, commission.retailerCommissionAmount); // Effectively adds to balance
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
      await globalTransaction.save();
    } else if (providerResponse.status === 'FAILED') {
      // Release Wallet Reservation
      await walletService.releaseReservation(userId, amount);
      globalTransaction.status = 'failed';
      globalTransaction.apiReference = providerResponse.providerTransactionId;
      await globalTransaction.save();
    } else if (providerResponse.status === 'PENDING') {
      globalTransaction.status = 'pending';
      globalTransaction.apiReference = providerResponse.providerTransactionId;
      await globalTransaction.save();
    }

    await transaction.save();

    // Send 200 OK for both SUCCESS and PENDING, but send accurate status inside payload
    if (providerResponse.status === 'SUCCESS' || providerResponse.status === 'PENDING') {
      const isPending = providerResponse.status === 'PENDING';
      res.status(200).json({
        success: true,
        message: isPending ? 'Recharge pending verification' : 'Recharge successful',
        data: {
          transactionId: transaction.orderId,
          referenceId: transaction.orderId, // Flutter uses this
          operatorRef: transaction.operatorReference || transaction.providerTransactionId || 'Processing...',
          status: isPending ? 'pending' : 'success',
          amountPaise: transaction.amount * 100,
          commissionEarnedPaise: transaction.commissionCalculated ? (await CommissionHistory.findOne({ transactionId: transaction._id })).retailerCommissionAmount * 100 : 0,
          walletDebitedPaise: paymentMode === 'wallet' ? transaction.amount * 100 : 0,
          walletBalanceAfterPaise: 0, // Optionally lookup wallet balance
          mobileNumber: transaction.mobileNumber,
          operatorName: operator.name.toUpperCase(),
          timestamp: transaction.createdAt
        }
      });
    } else {
      res.status(400).json({
        success: false,
        message: providerResponse.message || 'Recharge failed at provider',
      });
    }

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

    if (!transaction.providerTransactionId) {
      res.status(400);
      throw new Error('No provider transaction ID associated with this order.');
    }

    const statusResponse = await a1TopupProvider.status(transaction.providerTransactionId);

    // If status changed to SUCCESS from PENDING, we must run commission/ledger logic
    if (transaction.status === 'PENDING' && statusResponse.status === 'SUCCESS') {
      transaction.status = 'SUCCESS';
      transaction.operatorReference = statusResponse.operatorReference;
      
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
        apiReference: statusResponse.providerTransactionId,
        commissionEarnedPaise: commission.retailerCommissionAmount * 100 
      });

      transaction.commissionCalculated = true;
    } else if (transaction.status === 'PENDING' && statusResponse.status === 'FAILED') {
      transaction.status = 'FAILED';
      transaction.failureReason = statusResponse.message;
      await walletService.releaseReservation(transaction.userId, transaction.amount);
      
      await Transaction.updateOne({ referenceId: transaction.orderId }, { 
        status: 'failed', 
        apiReference: statusResponse.providerTransactionId 
      });
    }
    
    await transaction.save();

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
      transaction.status = 'SUCCESS';
      if (opid) transaction.operatorReference = opid;
      
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
      transaction.commissionCalculated = true;
    } else if (normalizedStatus === 'FAILED') {
      transaction.status = 'FAILED';
      transaction.failureReason = message || 'Failed at provider end';
      
      await walletService.releaseReservation(transaction.userId, transaction.amount);
      
      await Transaction.updateOne({ referenceId: transaction.orderId }, { 
         status: 'failed', 
         apiReference: actualTxId 
      });
    }

    await transaction.save();
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
