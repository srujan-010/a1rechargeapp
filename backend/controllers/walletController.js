const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');
const Notification = require('../models/Notification');

const getTransactionTitle = (serviceType, operatorName) => {
  const serviceMap = {
    'mobile': 'Mobile Recharge',
    'mobile_recharge': 'Mobile Recharge',
    'dth': 'DTH Recharge',
    'wallet_topup': 'Wallet Top-up',
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

// @desc    Get wallet balance
// @route   GET /api/wallet/balance
// @access  Private
const getBalance = async (req, res, next) => {
  try {
    const wallet = await Wallet.findOne({ userId: req.user._id });
    
    if (!wallet) {
      res.status(404);
      throw new Error('Wallet not found');
    }

    res.status(200).json({
      success: true,
      data: {
        balancePaise: wallet.balancePaise,
        onHoldPaise: wallet.onHoldPaise,
        availablePaise: wallet.balancePaise - wallet.onHoldPaise,
        currency: wallet.currency
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
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    const transactions = await Transaction.find({ userId: req.user._id })
      .sort({ createdAt: -1 })
      .skip(Number(skip))
      .limit(Number(limit));

    res.status(200).json({
      success: true,
      data: transactions.map(t => ({
        id: t._id,
        serviceType: t.service,
        operatorName: t.operatorName || '',
        transactionTitle: getTransactionTitle(t.service, t.operatorName),
        customerIdentifier: t.mobileNumber || t.recipientName || '',
        amount: t.amountPaise,
        commission: t.commissionEarnedPaise || 0,
        status: t.status,
        createdAt: t.createdAt.toISOString(),
        completedAt: (t.updatedAt || t.createdAt).toISOString(),
        paymentMethod: t.paymentMethod || 'wallet',
        referenceNumber: t.referenceId,
        apiReference: t.apiReference || ''
      }))
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
    const { amountPaise } = req.body;
    
    if (!amountPaise || amountPaise <= 0) {
      res.status(400);
      throw new Error('Please include a valid amount in paise');
    }

    let wallet = await Wallet.findOne({ userId: req.user._id });
    if (!wallet) {
      wallet = await Wallet.create({
        userId: req.user._id,
        balancePaise: 0
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

// @desc    Get dashboard summary (business metrics)
// @route   GET /api/wallet/summary
// @access  Private
const getDashboardSummary = async (req, res, next) => {
  try {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const transactions = await Transaction.find({
      userId: req.user._id,
      createdAt: { $gte: todayStart }
    });

    let todayRechargeAmount = 0;
    let todayCommission = 0;
    let todayTransactions = 0;
    let successfulTransactions = 0;
    let failedTransactions = 0;
    let pendingTransactions = 0;

    for (const tx of transactions) {
      if (tx.service !== 'wallet_topup' && tx.service !== 'commission') {
        todayTransactions++;
        if (tx.status === 'success') successfulTransactions++;
        if (tx.status === 'failed') failedTransactions++;
        if (tx.status === 'pending') pendingTransactions++;
        
        if (tx.type === 'debit') {
          todayRechargeAmount += tx.amountPaise;
        }
      }
      
      if (tx.service === 'commission' && tx.type === 'credit') {
        todayCommission += tx.amountPaise;
      }
    }

    res.status(200).json({
      success: true,
      data: {
        todayRechargeAmount,
        todayCommission,
        todayTransactions,
        successfulTransactions,
        failedTransactions,
        pendingTransactions
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
      currentStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      currentEnd = new Date(currentStart.getTime() + 24 * 60 * 60 * 1000);
      prevStart = new Date(currentStart.getTime() - 24 * 60 * 60 * 1000);
      prevEnd = currentStart;
    } else if (period === 'week') {
      // Last 7 days
      currentStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      currentEnd = now;
      prevStart = new Date(currentStart.getTime() - 7 * 24 * 60 * 60 * 1000);
      prevEnd = currentStart;
    } else if (period === 'month') {
      // Last 30 days
      currentStart = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      currentEnd = now;
      prevStart = new Date(currentStart.getTime() - 30 * 24 * 60 * 60 * 1000);
      prevEnd = currentStart;
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
        } else if (tx.service !== 'wallet_topup' && tx.service !== 'commission') {
          count++;
          if (tx.type === 'debit') {
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
