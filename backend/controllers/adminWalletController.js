const User = require('../models/User');
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const Transaction = require('../models/Transaction');
const AdminAuditLog = require('../models/AdminAuditLog');
const Notification = require('../models/Notification');
const notificationService = require('../services/notification.service');

/**
 * @desc    Credit retailer wallet manually (Admin Only)
 * @route   POST /api/admin/wallet/credit
 * @access  Private/Admin
 */
const creditRetailerWallet = async (req, res, next) => {
  try {
    const { retailerUserId, retailerId, phone, amountRupees, amountPaise, remark, referenceId } = req.body;

    // 1. Calculate amount in paise
    let parsedPaise = 0;
    if (amountPaise && Number(amountPaise) > 0) {
      parsedPaise = Math.round(Number(amountPaise));
    } else if (amountRupees && Number(amountRupees) > 0) {
      parsedPaise = Math.round(Number(amountRupees) * 100);
    } else if (req.body.amount && Number(req.body.amount) > 0) {
      parsedPaise = Math.round(Number(req.body.amount) * 100);
    }

    if (!parsedPaise || parsedPaise <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Please enter a valid credit amount',
      });
    }

    // 2. Find retailer
    let retailerUser = null;
    if (retailerUserId) {
      retailerUser = await User.findById(retailerUserId);
    } else if (retailerId) {
      retailerUser = await User.findOne({ retailerId });
    } else if (phone) {
      retailerUser = await User.findOne({ phone });
    }

    if (!retailerUser) {
      return res.status(404).json({
        success: false,
        message: 'Retailer not found',
      });
    }

    // 3. Idempotency Check
    const effectiveRefId = referenceId || `ADM_CREDIT_${Date.now()}_${Math.floor(Math.random() * 100000)}`;

    const existingAudit = await AdminAuditLog.findOne({ referenceId: effectiveRefId });
    if (existingAudit) {
      const wallet = await Wallet.findOne({ userId: retailerUser._id });
      return res.status(200).json({
        success: true,
        message: 'Credit request already processed (idempotent response)',
        data: {
          isDuplicate: true,
          referenceId: existingAudit.referenceId,
          retailer: {
            id: retailerUser._id,
            retailerId: retailerUser.retailerId,
            name: retailerUser.name,
            phone: retailerUser.phone,
          },
          amountRupees: existingAudit.amountRupees,
          previousBalanceRupees: existingAudit.previousBalanceRupees,
          newBalanceRupees: existingAudit.newBalanceRupees,
          currentBalanceRupees: wallet ? wallet.balancePaise / 100 : existingAudit.newBalanceRupees,
          remark: existingAudit.remark,
          createdAt: existingAudit.createdAt,
        },
      });
    }

    // 4. Get previous balance and update atomically
    let wallet = await Wallet.findOne({ userId: retailerUser._id });
    const previousBalancePaise = wallet ? wallet.balancePaise : 0;

    const updatedWallet = await Wallet.findOneAndUpdate(
      { userId: retailerUser._id },
      { $inc: { balancePaise: parsedPaise } },
      { new: true, upsert: true }
    );

    const newBalancePaise = updatedWallet.balancePaise;
    const amountRupeesVal = Number((parsedPaise / 100).toFixed(2));
    const prevRupeesVal = Number((previousBalancePaise / 100).toFixed(2));
    const newRupeesVal = Number((newBalancePaise / 100).toFixed(2));
    const remarkText = remark && remark.trim().length > 0 ? remark.trim() : 'Wallet credited by administrator';

    // 5. Create WalletLedger record
    await WalletLedger.create({
      userId: retailerUser._id,
      adminId: req.user._id,
      transactionType: 'CREDIT',
      amount: amountRupeesVal,
      previousBalance: prevRupeesVal,
      balanceAfter: newRupeesVal,
      referenceType: 'ADMIN_CREDIT',
      referenceId: effectiveRefId,
      remark: remarkText,
      description: remarkText,
    });

    // 6. Create Transaction record (for retailer statement)
    const transaction = await Transaction.create({
      userId: retailerUser._id,
      type: 'credit',
      amountPaise: parsedPaise,
      status: 'success',
      service: 'admin_credit',
      referenceId: effectiveRefId,
      description: remarkText,
      closingBalancePaise: newBalancePaise,
      recipientName: retailerUser.name,
      completedAt: new Date(),
    });

    // 7. Create AdminAuditLog entry
    const auditLog = await AdminAuditLog.create({
      adminId: req.user._id,
      adminName: req.user.name,
      adminPhone: req.user.phone,
      retailerUserId: retailerUser._id,
      retailerId: retailerUser.retailerId,
      retailerName: retailerUser.name,
      retailerPhone: retailerUser.phone,
      amountRupees: amountRupeesVal,
      amountPaise: parsedPaise,
      previousBalanceRupees: prevRupeesVal,
      previousBalancePaise,
      newBalanceRupees: newRupeesVal,
      newBalancePaise,
      remark: remarkText,
      referenceId: effectiveRefId,
    });

    // 8. Create Notification for retailer via Central Notification Service
    try {
      notificationService.notifyAdminWalletCredit({
        userId: retailerUser._id,
        amount: amountRupeesVal,
        referenceId: effectiveRefId
      });
    } catch (err) {
      console.error('Failed to create notification for admin credit:', err);
    }

    return res.status(200).json({
      success: true,
      message: `Successfully credited ₹${amountRupeesVal.toFixed(2)} to ${retailerUser.name}`,
      data: {
        referenceId: effectiveRefId,
        transactionId: transaction._id,
        auditLogId: auditLog._id,
        retailer: {
          id: retailerUser._id,
          retailerId: retailerUser.retailerId,
          name: retailerUser.name,
          phone: retailerUser.phone,
        },
        amountRupees: amountRupeesVal,
        amountPaise: parsedPaise,
        previousBalanceRupees: prevRupeesVal,
        newBalanceRupees: newRupeesVal,
        remark: remarkText,
        createdAt: auditLog.createdAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Search retailers for admin wallet credit
 * @route   GET /api/admin/retailers/search
 * @access  Private/Admin
 */
const searchRetailers = async (req, res, next) => {
  try {
    const { query = '' } = req.query;

    let filter = {};
    if (query.trim()) {
      const q = query.trim();
      filter = {
        $or: [
          { name: { $regex: q, $options: 'i' } },
          { phone: { $regex: q, $options: 'i' } },
          { retailerId: { $regex: q, $options: 'i' } },
          { shopName: { $regex: q, $options: 'i' } },
        ],
      };
    }

    const retailers = await User.find(filter)
      .select('_id retailerId name phone shopName role kycStatus createdAt')
      .sort({ name: 1 })
      .limit(50)
      .lean();

    const retailerUserIds = retailers.map(r => r._id);
    const wallets = await Wallet.find({ userId: { $in: retailerUserIds } }).lean();

    const walletMap = {};
    wallets.forEach(w => {
      walletMap[w.userId.toString()] = {
        balancePaise: w.balancePaise || 0,
        onHoldPaise: w.onHoldPaise || 0,
        availablePaise: (w.balancePaise || 0) - (w.onHoldPaise || 0),
      };
    });

    const result = retailers.map(r => {
      const w = walletMap[r._id.toString()] || { balancePaise: 0, onHoldPaise: 0, availablePaise: 0 };
      return {
        id: r._id,
        retailerId: r.retailerId,
        name: r.name,
        phone: r.phone,
        shopName: r.shopName || '',
        role: r.role || 'retailer',
        kycStatus: r.kycStatus || 'notStarted',
        balancePaise: w.balancePaise,
        balanceRupees: Number((w.balancePaise / 100).toFixed(2)),
        onHoldRupees: Number((w.onHoldPaise / 100).toFixed(2)),
        availableRupees: Number((w.availablePaise / 100).toFixed(2)),
      };
    });

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get admin wallet credit audit logs
 * @route   GET /api/admin/audit-logs
 * @access  Private/Admin
 */
const getAuditLogs = async (req, res, next) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    const logs = await AdminAuditLog.find()
      .sort({ createdAt: -1 })
      .skip(Number(skip))
      .limit(Number(limit))
      .lean();

    const total = await AdminAuditLog.countDocuments();

    res.status(200).json({
      success: true,
      total,
      page: Number(page),
      limit: Number(limit),
      data: logs.map(l => ({
        id: l._id,
        adminName: l.adminName,
        adminPhone: l.adminPhone,
        retailerId: l.retailerId,
        retailerName: l.retailerName,
        retailerPhone: l.retailerPhone,
        amountRupees: l.amountRupees,
        previousBalanceRupees: l.previousBalanceRupees,
        newBalanceRupees: l.newBalanceRupees,
        remark: l.remark,
        referenceId: l.referenceId,
        createdAt: l.createdAt,
      })),
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get Razorpay & online wallet funding transactions (Admin Only)
 * @route   GET /api/admin/wallet-funding-transactions
 * @access  Private/Admin
 */
const getFundingTransactions = async (req, res, next) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    const WalletFundingTransaction = require('../models/WalletFundingTransaction');

    const txns = await WalletFundingTransaction.find()
      .populate('userId', 'name phone retailerId shopName')
      .sort({ createdAt: -1 })
      .skip(Number(skip))
      .limit(Number(limit))
      .lean();

    const total = await WalletFundingTransaction.countDocuments();

    res.status(200).json({
      success: true,
      total,
      page: Number(page),
      limit: Number(limit),
      data: txns.map(t => ({
        id: t._id,
        internalTransactionId: t.internalTransactionId,
        retailer: {
          id: t.userId?._id,
          name: t.userId?.name || 'Retailer',
          phone: t.userId?.phone || '',
          retailerId: t.userId?.retailerId || '',
          shopName: t.userId?.shopName || '',
        },
        amountRupees: t.amountRupees,
        amountPaise: t.amountPaise,
        currency: t.currency || 'INR',
        razorpayOrderId: t.razorpayOrderId || '',
        razorpayPaymentId: t.razorpayPaymentId || '',
        status: t.status,
        fundingMethod: t.fundingMethod || 'RAZORPAY',
        failureReason: t.failureReason || null,
        createdAt: t.createdAt,
      })),
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Deduct/debit retailer wallet manually (Admin Only)
 * @route   POST /api/admin/wallet/debit
 * @access  Private/Admin
 */
const debitRetailerWallet = async (req, res, next) => {
  try {
    const { retailerUserId, retailerId, phone, amountRupees, amountPaise, remark, referenceId } = req.body;

    // 1. Calculate amount in paise
    let parsedPaise = 0;
    if (amountPaise && Number(amountPaise) > 0) {
      parsedPaise = Math.round(Number(amountPaise));
    } else if (amountRupees && Number(amountRupees) > 0) {
      parsedPaise = Math.round(Number(amountRupees) * 100);
    } else if (req.body.amount && Number(req.body.amount) > 0) {
      parsedPaise = Math.round(Number(req.body.amount) * 100);
    }

    if (!parsedPaise || parsedPaise <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Please enter a valid debit amount',
      });
    }

    // 2. Find retailer
    let retailerUser = null;
    if (retailerUserId) {
      retailerUser = await User.findById(retailerUserId);
    } else if (retailerId) {
      retailerUser = await User.findOne({ retailerId });
    } else if (phone) {
      retailerUser = await User.findOne({ phone });
    }

    if (!retailerUser) {
      return res.status(404).json({
        success: false,
        message: 'Retailer not found',
      });
    }

    // 3. Idempotency Check
    const effectiveRefId = referenceId || `ADM_DEBIT_${Date.now()}_${Math.floor(Math.random() * 100000)}`;

    const existingAudit = await AdminAuditLog.findOne({ referenceId: effectiveRefId });
    if (existingAudit) {
      const wallet = await Wallet.findOne({ userId: retailerUser._id });
      return res.status(200).json({
        success: true,
        message: 'Debit request already processed (idempotent response)',
        data: {
          isDuplicate: true,
          referenceId: existingAudit.referenceId,
          retailer: {
            id: retailerUser._id,
            retailerId: retailerUser.retailerId,
            name: retailerUser.name,
            phone: retailerUser.phone,
          },
          amountRupees: existingAudit.amountRupees,
          previousBalanceRupees: existingAudit.previousBalanceRupees,
          newBalanceRupees: existingAudit.newBalanceRupees,
          currentBalanceRupees: wallet ? wallet.balancePaise / 100 : existingAudit.newBalanceRupees,
          remark: existingAudit.remark,
          createdAt: existingAudit.createdAt,
        },
      });
    }

    // 4. Get previous balance and update atomically
    let wallet = await Wallet.findOne({ userId: retailerUser._id });
    const previousBalancePaise = wallet ? wallet.balancePaise : 0;

    if (previousBalancePaise < parsedPaise) {
      return res.status(400).json({
        success: false,
        message: `Insufficient wallet balance for debit. Available: ₹${(previousBalancePaise / 100).toFixed(2)}`,
      });
    }

    const updatedWallet = await Wallet.findOneAndUpdate(
      { userId: retailerUser._id },
      { $inc: { balancePaise: -parsedPaise } },
      { new: true, upsert: true }
    );

    const newBalancePaise = updatedWallet.balancePaise;
    const amountRupeesVal = Number((parsedPaise / 100).toFixed(2));
    const prevRupeesVal = Number((previousBalancePaise / 100).toFixed(2));
    const newRupeesVal = Number((newBalancePaise / 100).toFixed(2));
    const remarkText = remark && remark.trim().length > 0 ? remark.trim() : 'Wallet debited by administrator';

    // 5. Create WalletLedger record
    await WalletLedger.create({
      userId: retailerUser._id,
      adminId: req.user._id,
      transactionType: 'DEBIT',
      amount: amountRupeesVal,
      previousBalance: prevRupeesVal,
      balanceAfter: newRupeesVal,
      referenceType: 'ADMIN_DEBIT',
      referenceId: effectiveRefId,
      remark: remarkText,
      description: remarkText,
    });

    // 6. Create Transaction record (for retailer statement)
    const transaction = await Transaction.create({
      userId: retailerUser._id,
      type: 'debit',
      amountPaise: parsedPaise,
      status: 'success',
      service: 'admin_debit',
      referenceId: effectiveRefId,
      description: remarkText,
      closingBalancePaise: newBalancePaise,
      recipientName: retailerUser.name,
      completedAt: new Date(),
    });

    // 7. Create AdminAuditLog entry
    const auditLog = await AdminAuditLog.create({
      adminId: req.user._id,
      adminName: req.user.name,
      adminPhone: req.user.phone,
      retailerUserId: retailerUser._id,
      retailerId: retailerUser.retailerId,
      retailerName: retailerUser.name,
      retailerPhone: retailerUser.phone,
      amountRupees: amountRupeesVal,
      amountPaise: parsedPaise,
      previousBalanceRupees: prevRupeesVal,
      previousBalancePaise,
      newBalanceRupees: newRupeesVal,
      newBalancePaise,
      remark: remarkText,
      referenceId: effectiveRefId,
    });

    return res.status(200).json({
      success: true,
      message: `Successfully debited ₹${amountRupeesVal.toFixed(2)} from ${retailerUser.name}`,
      data: {
        referenceId: effectiveRefId,
        transactionId: transaction._id,
        auditLogId: auditLog._id,
        retailer: {
          id: retailerUser._id,
          retailerId: retailerUser.retailerId,
          name: retailerUser.name,
          phone: retailerUser.phone,
        },
        amountRupees: amountRupeesVal,
        amountPaise: parsedPaise,
        previousBalanceRupees: prevRupeesVal,
        newBalanceRupees: newRupeesVal,
        remark: remarkText,
        createdAt: auditLog.createdAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  creditRetailerWallet,
  debitRetailerWallet,
  searchRetailers,
  getAuditLogs,
  getFundingTransactions,
};

