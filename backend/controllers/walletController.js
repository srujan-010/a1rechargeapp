const mongoose = require('mongoose');
const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');
const RechargeTransaction = require('../models/RechargeTransaction');
const Notification = require('../models/Notification');

const { getWalletFundingMode, isPaymentGatewayEnabled } = require('../config/walletConfig');

const getTransactionTitle = (serviceType, operatorName) => {
  const serviceMap = {
    'mobile': 'Mobile Recharge',
    'mobile_recharge': 'Mobile Recharge',
    'dth': 'DTH Recharge',
    'wallet_topup': 'Wallet Top-up',
    'admin_credit': 'ADMIN CREDIT',
    'commission': 'Commission Earned',
    'dmt': 'Money Transfer',
    'aeps': 'AEPS Withdrawal',
  };

  if (serviceMap[serviceType]) {
    return serviceMap[serviceType];
  }

  // Handle BBPS categories dynamically based on operator/biller name or fallback
  if (serviceType === 'bbps') {
    if (!operatorName) return 'Bill Payment';
    const name = operatorName.toLowerCase();
    if (name.includes('electricity') || name.includes('power') || name.includes('pdcl')) return 'Electricity Bill';
    if (name.includes('water')) return 'Water Bill';
    if (name.includes('gas')) return 'Gas Bill';
    if (name.includes('broadband')) return 'Broadband Bill';
    if (name.includes('postpaid')) return 'Postpaid Bill';
    if (name.includes('fastag')) return 'FASTag Recharge';
    return 'Bill Payment';
  }

  // Fallback
  return serviceType.charAt(0).toUpperCase() + serviceType.slice(1).replace('_', ' ');
};

// @desc    Get wallet balance (Find or Create single canonical wallet)
// @route   GET /api/wallet/balance
// @access  Private
const getBalance = async (req, res, next) => {
  try {
    let wallet = await Wallet.findOne({ userId: req.user._id });
    
    if (!wallet) {
      console.log(`[WALLET] Initializing new wallet for user: ${req.user._id}`);
      wallet = await Wallet.create({
        userId: req.user._id,
        balancePaise: 0,
        onHoldPaise: 0,
        currency: 'INR',
      });
    }

    res.status(200).json({
      success: true,
      data: {
        balancePaise: wallet.balancePaise || 0,
        onHoldPaise: wallet.onHoldPaise || 0,
        availablePaise: (wallet.balancePaise || 0) - (wallet.onHoldPaise || 0),
        currency: wallet.currency || 'INR',
        walletFundingMode: getWalletFundingMode(),
      }
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get wallet statement (transactions)
// @route   GET /api/wallet/statement
// @access  Private
const getStatement = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, type, days } = req.query;

    const userIds = [req.user._id];
    if (req.user._id && typeof req.user._id.toString === 'function') {
      userIds.push(req.user._id.toString());
    }

    const baseQuery = { userId: { $in: userIds } };

    if (days && !isNaN(Number(days))) {
      const daysNum = Number(days);
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - daysNum);
      baseQuery.createdAt = { $gte: startDate };
    }

    const txQuery = { ...baseQuery };

    if (type === 'credits' || type === 'credit') {
      txQuery.$or = [
        { type: 'credit' },
        { service: { $in: ['wallet_topup', 'commission', 'admin_credit'] } }
      ];
    } else if (type === 'debits' || type === 'debit') {
      txQuery.$or = [
        { type: 'debit' },
        { service: { $nin: ['wallet_topup', 'commission', 'admin_credit'] } }
      ];
    }

    const globalTransactions = await Transaction.find(txQuery)
      .sort({ createdAt: -1 })
      .lean()
      .maxTimeMS(3000);

    const formattedGlobal = globalTransactions.map(t => {
      const isCred = t.type === 'credit' || t.service === 'wallet_topup' || t.service === 'commission' || t.service === 'admin_credit';
      const refNo = t.referenceNumber || t.referenceId || t.orderId || (t.metadata && t.metadata.orderId) || '';
      const mobile = t.mobileNumber || t.customerIdentifier || t.recipientName || (t.metadata && t.metadata.customerNumber) || '';
      const opName = t.operatorName || (t.metadata && t.metadata.operator) || (t.operatorId ? t.operatorId : 'Operator');

      return {
        id: String(t._id),
        type: isCred ? 'credit' : 'debit',
        serviceType: t.serviceType || t.service || 'mobile_recharge',
        operatorName: opName,
        operatorId: t.operatorId || null,
        transactionTitle: t.service === 'admin_credit' ? 'ADMIN CREDIT' : getTransactionTitle(t.service || 'mobile_recharge', opName),
        customerIdentifier: mobile,
        amount: t.amountPaise || Math.round((t.amount || 0) * 100),
        commission: t.commissionEarnedPaise || Math.round((t.commission || 0) * 100),
        status: String(t.status || 'pending').toLowerCase(),
        createdAt: (t.createdAt instanceof Date ? t.createdAt : new Date(t.createdAt)).toISOString(),
        completedAt: ((t.updatedAt || t.createdAt) instanceof Date ? (t.updatedAt || t.createdAt) : new Date(t.updatedAt || t.createdAt)).toISOString(),
        updatedAt: (t.updatedAt instanceof Date ? t.updatedAt : new Date(t.updatedAt || t.createdAt)).toISOString(),
        paymentMethod: t.paymentMethod || 'wallet',
        referenceNumber: refNo,
        clientOrderId: refNo,
        apiReference: t.apiReference || t.providerTransactionId || '',
        providerTransactionId: t.providerTransactionId || t.apiReference || null,
        failureReason: t.failureReason || null,
        providerMessage: t.providerMessage || null,
        description: t.description || `Transaction for ${mobile || 'account'}`,
      };
    });

    // Also query RechargeTransaction collection to ensure all recharge records are present
    let formattedRecharges = [];
    if (!type || type === 'all' || type === 'debits' || type === 'debit') {
      const rechargeTxns = await RechargeTransaction.find(baseQuery)
        .sort({ createdAt: -1 })
        .lean()
        .maxTimeMS(3000);

      const existingRefIds = new Set(formattedGlobal.map(t => t.referenceNumber).filter(Boolean));
      const existingIds = new Set(formattedGlobal.map(t => t.id));

      formattedRecharges = rechargeTxns
        .filter(r => !existingRefIds.has(r.orderId) && !existingIds.has(String(r._id)))
        .map(r => {
          const serviceType = r.serviceType === 'dth' ? 'dth' : 'mobile_recharge';
          return {
            id: String(r._id),
            type: 'debit',
            serviceType,
            operatorName: r.internalOperatorName || r.operatorCode || 'Operator',
            operatorId: r.operatorCode || null,
            transactionTitle: serviceType === 'dth' ? 'DTH Recharge' : 'Mobile Recharge',
            customerIdentifier: r.mobileNumber || '',
            amount: Math.round((r.amount || 0) * 100), // convert INR to paise
            commission: Math.round((r.commissionAmount || 0) * 100),
            status: String(r.status || 'pending').toLowerCase(),
            createdAt: (r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt)).toISOString(),
            completedAt: ((r.updatedAt || r.createdAt) instanceof Date ? (r.updatedAt || r.createdAt) : new Date(r.updatedAt || r.createdAt)).toISOString(),
            updatedAt: ((r.updatedAt || r.createdAt) instanceof Date ? (r.updatedAt || r.createdAt) : new Date(r.updatedAt || r.createdAt)).toISOString(),
            paymentMethod: r.paymentMethod || 'RAZORPAY_UPI',
            referenceNumber: r.orderId || '',
            clientOrderId: r.orderId || '',
            apiReference: r.providerTransactionId || '',
            providerTransactionId: r.providerTransactionId || null,
            failureReason: r.failureReason || null,
            providerMessage: r.providerMessage || null,
            description: `Recharge for ${r.mobileNumber}`,
          };
        });
    }

    const merged = [...formattedGlobal, ...formattedRecharges];
    merged.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    const pageNum = Number(page) || 1;
    const limitNum = Number(limit) || 20;
    const startIndex = (pageNum - 1) * limitNum;
    const paginated = merged.slice(startIndex, startIndex + limitNum);

    res.status(200).json({
      success: true,
      data: paginated,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Topup wallet balance (Add Money)
// @route   POST /api/wallet/topup
// @access  Private
const topupWallet = async (req, res, next) => {
  try {
    if (!isPaymentGatewayEnabled()) {
      return res.status(400).json({
        success: false,
        code: 'WALLET_FUNDING_DISABLED',
        message: 'Online wallet funding is currently unavailable. Please contact your administrator.'
      });
    }

    const { amountPaise } = req.body;
    
    if (!amountPaise || amountPaise <= 0) {
      res.status(400);
      throw new Error('Please include a valid amount in paise');
    }

    let wallet = await Wallet.findOne({ userId: req.user._id });
    if (!wallet) {
      wallet = await Wallet.create({
        userId: req.user._id,
        balancePaise: 0,
        onHoldPaise: 0,
        currency: 'INR'
      });
    }

    wallet.balancePaise += Number(amountPaise);
    await wallet.save();

    // Create a transaction record
    const transaction = await Transaction.create({
      userId: req.user._id,
      type: 'credit',
      amountPaise: Number(amountPaise),
      status: 'success',
      service: 'wallet_topup',
      referenceId: `TXN${Math.floor(Math.random() * 9000000) + 1000000}`,
      description: 'Wallet top-up via Payment Gateway',
      closingBalancePaise: wallet.balancePaise
    });

    await Notification.create({
      userId: req.user._id,
      title: 'Wallet Credited',
      message: `₹${(amountPaise / 100).toFixed(2)} has been added to your wallet.`,
      category: 'SUCCESS',
      priority: 'NORMAL',
      action: 'ROUTE_WALLET'
    });

    res.status(200).json({
      success: true,
      message: 'Wallet top-up successful',
      data: {
        balancePaise: wallet.balancePaise,
        transaction: {
          id: transaction._id,
          type: transaction.type,
          amountPaise: transaction.amountPaise,
          status: transaction.status,
          service: transaction.service,
          referenceId: transaction.referenceId,
          description: transaction.description,
          closingBalancePaise: transaction.closingBalancePaise,
          timestamp: transaction.createdAt
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// Helper to get IST date boundaries
const getISTDateBounds = (daysOffset = 0) => {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = formatter.formatToParts(now);
  const partMap = {};
  parts.forEach(p => partMap[p.type] = p.value);
  
  const istNowStr = `${partMap.year}-${partMap.month}-${partMap.day}T00:00:00.000+05:30`;
  const istMidnight = new Date(istNowStr);
  
  const targetStart = new Date(istMidnight.getTime() - daysOffset * 24 * 60 * 60 * 1000);
  const targetEnd = new Date(targetStart.getTime() + 24 * 60 * 60 * 1000 - 1);
  
  return { start: targetStart, end: targetEnd };
};

// @desc    Get dashboard summary (business metrics)
// @route   GET /api/wallet/summary
// @access  Private
const getDashboardSummary = async (req, res, next) => {
  try {
    const { start: todayStart, end: todayEnd } = getISTDateBounds(0);
    const userObjectId = new mongoose.Types.ObjectId(req.user._id);

    const rechargeTxList = await RechargeTransaction.find({
      userId: userObjectId,
      status: { $in: ['SUCCESS', 'PAYMENT_SUCCESS', 'completed', 'success', 'SUCCESSFUL'] },
      isTest: { $ne: true },
      orderId: { $not: /^TEST/i },
      $or: [
        { createdAt: { $gte: todayStart, $lte: todayEnd } },
        { completedAt: { $gte: todayStart, $lte: todayEnd } }
      ]
    }).lean();

    let totalRechargeAmountRupees = 0;
    let totalCommissionRupees = 0;
    let totalTransactionsCount = rechargeTxList.length;
    const includedTxIds = [];

    rechargeTxList.forEach(tx => {
      const amt = Number(tx.amount) || 0;
      const comm = Number(tx.commissionAmount) || 0;
      totalRechargeAmountRupees += amt;
      totalCommissionRupees += comm;
      includedTxIds.push(tx.orderId || tx._id.toString());

      console.log('\n[RETAILER DASHBOARD TRANSACTION INCLUDED]');
      console.log(`orderId: ${tx.orderId || tx._id}`);
      console.log(`retailerId: ${tx.userId}`);
      console.log(`amount: ₹${amt}`);
      console.log(`commissionAmount: ₹${comm}`);
      console.log(`status: ${tx.status}`);
      console.log(`paymentStatus: ${tx.paymentMethod || 'PAID'}`);
      console.log(`transactionDate: ${tx.completedAt || tx.createdAt}`);
    });

    // Fallback complement query on Transaction model
    if (totalTransactionsCount === 0) {
      const legacyTxList = await Transaction.find({
        userId: userObjectId,
        status: { $in: ['success', 'SUCCESS', 'completed'] },
        type: { $in: ['debit', 'recharge', 'payment'] },
        isTest: { $ne: true },
        referenceId: { $not: /^TEST/i },
        service: { $nin: ['wallet_topup', 'commission', 'admin_credit'] },
        createdAt: { $gte: todayStart, $lte: todayEnd }
      }).lean();

      totalTransactionsCount = legacyTxList.length;
      legacyTxList.forEach(tx => {
        const amtRupees = (Number(tx.amountPaise) || 0) / 100 || Number(tx.amount) || 0;
        const commRupees = (Number(tx.commissionEarnedPaise) || 0) / 100 || Number(tx.commissionAmount) || 0;
        totalRechargeAmountRupees += amtRupees;
        totalCommissionRupees += commRupees;
        includedTxIds.push(tx.referenceId || tx._id.toString());
      });
    }

    const todayRechargeAmountPaise = Math.round(totalRechargeAmountRupees * 100);
    const todayCommissionPaise = Math.round(totalCommissionRupees * 100);

    console.log('\n====================================================');
    console.log('[RETAILER DASHBOARD SUMMARY]');
    console.log(`[SUMMARY-1] authenticated retailer: ${userObjectId.toString()}`);
    console.log(`[SUMMARY-2] DB matched transactions: ${rechargeTxList.length}`);
    console.log(`[SUMMARY-3] calculated recharge paise: ${todayRechargeAmountPaise}`);
    console.log(`[SUMMARY-4] calculated commission paise: ${todayCommissionPaise}`);
    console.log(`[SUMMARY-5] calculated transaction count: ${totalTransactionsCount}`);
    console.log(`[SUMMARY-6] JSON response: ${JSON.stringify({ todayRechargeAmountPaise, todayCommissionPaise, todayTransactions: totalTransactionsCount })}`);
    console.log('====================================================\n');

    res.status(200).json({
      success: true,
      data: {
        todayRechargeAmount: totalRechargeAmountRupees,
        todayRechargeAmountPaise: todayRechargeAmountPaise,
        todayCommission: totalCommissionRupees,
        todayCommissionPaise: todayCommissionPaise,
        todayTransactions: totalTransactionsCount,
        successfulTransactions: totalTransactionsCount,
        failedTransactions: 0,
        pendingTransactions: 0
      }
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get dashboard analytics (business metrics with period comparison)
// @route   GET /api/wallet/analytics
// @access  Private
const getDashboardAnalytics = async (req, res, next) => {
  try {
    const { period = 'today' } = req.query; // today, week, month

    const now = new Date();
    let currentStart, currentEnd, prevStart, prevEnd;

    if (period === 'today') {
      const current = getISTDateBounds(0);
      currentStart = current.start;
      currentEnd = current.end;
      const prev = getISTDateBounds(1);
      prevStart = prev.start;
      prevEnd = prev.end;
    } else if (period === 'week') {
      // Last 7 days
      const current = getISTDateBounds(0);
      currentStart = new Date(current.start.getTime() - 6 * 24 * 60 * 60 * 1000);
      currentEnd = current.end;
      prevStart = new Date(currentStart.getTime() - 7 * 24 * 60 * 60 * 1000);
      prevEnd = new Date(currentStart.getTime() - 1);
    } else if (period === 'month') {
      // Last 30 days
      const current = getISTDateBounds(0);
      currentStart = new Date(current.start.getTime() - 29 * 24 * 60 * 60 * 1000);
      currentEnd = current.end;
      prevStart = new Date(currentStart.getTime() - 30 * 24 * 60 * 60 * 1000);
      prevEnd = new Date(currentStart.getTime() - 1);
    }

    const [currentTransactions, prevTransactions] = await Promise.all([
      Transaction.find({
        userId: req.user._id,
        createdAt: { $gte: currentStart, $lt: currentEnd }
      }),
      Transaction.find({
        userId: req.user._id,
        createdAt: { $gte: prevStart, $lt: prevEnd }
      })
    ]);

    const calculateMetrics = (txns) => {
      let commission = 0;
      let recharge = 0;
      let count = 0;
      for (const tx of txns) {
        if (tx.service === 'commission' && tx.type === 'credit') {
          commission += tx.amountPaise;
        } else if (tx.service !== 'wallet_topup' && tx.service !== 'commission' && tx.service !== 'admin_credit') {
          count++;
          if (tx.type === 'debit' && tx.status === 'success') {
            recharge += tx.amountPaise;
          }
        }
      }
      return { commission, recharge, transactions: count };
    };

    res.status(200).json({
      success: true,
      data: {
        currentPeriod: calculateMetrics(currentTransactions),
        previousPeriod: calculateMetrics(prevTransactions)
      }
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getBalance,
  getStatement,
  topupWallet,
  getDashboardSummary,
  getDashboardAnalytics,
};
