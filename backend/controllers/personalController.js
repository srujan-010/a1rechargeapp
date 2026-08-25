const mongoose = require('mongoose');
const RechargeTransaction = require('../models/RechargeTransaction');
const PersonalCommissionSlab = require('../models/PersonalCommissionSlab');
const OperatorCommission = require('../models/OperatorCommission');

/**
 * Seed default Personal Commission Slabs if none exist
 */
const defaultPersonalSlabs = [
  // Mobile
  { operatorCode: 'AT', operatorName: 'Airtel', serviceType: 'mobile', commissionType: 'percentage', commissionValue: 0.80, status: 'ACTIVE' },
  { operatorCode: 'JO', operatorName: 'Jio', serviceType: 'mobile', commissionType: 'percentage', commissionValue: 0.70, status: 'ACTIVE' },
  { operatorCode: 'VI', operatorName: 'Vi', serviceType: 'mobile', commissionType: 'percentage', commissionValue: 0.80, status: 'ACTIVE' },
  { operatorCode: 'BT', operatorName: 'BSNL', serviceType: 'mobile', commissionType: 'percentage', commissionValue: 1.20, status: 'ACTIVE' },
  // DTH
  { operatorCode: 'DT', operatorName: 'Tata Play', serviceType: 'dth', commissionType: 'percentage', commissionValue: 1.00, status: 'ACTIVE' },
  { operatorCode: 'DA', operatorName: 'Airtel DTH', serviceType: 'dth', commissionType: 'percentage', commissionValue: 0.80, status: 'ACTIVE' },
  { operatorCode: 'DD', operatorName: 'Dish TV', serviceType: 'dth', commissionType: 'percentage', commissionValue: 0.90, status: 'ACTIVE' },
  { operatorCode: 'DS', operatorName: 'Sun Direct', serviceType: 'dth', commissionType: 'percentage', commissionValue: 1.10, status: 'ACTIVE' },
  // Electricity
  { operatorCode: 'ELE', operatorName: 'Electricity Bill', serviceType: 'electricity', commissionType: 'percentage', commissionValue: 0.50, status: 'ACTIVE' },
];

/**
 * GET /api/personal/savings
 * Calculates lifetime savings, current month savings, and previous month savings
 */
const getSavings = async (req, res) => {
  try {
    const userId = req.user._id;
    const now = new Date();
    const startOfCurrentMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfPrevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const endOfPrevMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);

    // Fetch all SUCCESS transactions for user
    const transactions = await RechargeTransaction.find({
      userId,
      status: 'SUCCESS',
    }).lean();

    let lifetimeSavings = 0;
    let monthlySavings = 0;
    let previousMonthSavings = 0;

    for (const txn of transactions) {
      const savings = Number(txn.commissionAmount || 0);
      lifetimeSavings += savings;

      const txnDate = new Date(txn.createdAt);
      if (txnDate >= startOfCurrentMonth) {
        monthlySavings += savings;
      } else if (txnDate >= startOfPrevMonth && txnDate <= endOfPrevMonth) {
        previousMonthSavings += savings;
      }
    }

    return res.status(200).json({
      success: true,
      data: {
        lifetimeSavings: Number(lifetimeSavings.toFixed(2)),
        monthlySavings: Number(monthlySavings.toFixed(2)),
        previousMonthSavings: Number(previousMonthSavings.toFixed(2)),
        totalCompletedCount: transactions.length,
      },
    });
  } catch (error) {
    console.error('[getSavings Error]:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/personal/benefits
 * Returns active personal benefit slabs grouped by service type
 */
const getBenefits = async (req, res) => {
  try {
    let count = await PersonalCommissionSlab.countDocuments();
    if (count === 0) {
      await PersonalCommissionSlab.insertMany(defaultPersonalSlabs);
    }

    const slabs = await PersonalCommissionSlab.find({ status: 'ACTIVE' }).lean();

    // Group slabs by serviceType
    const mobile = slabs.filter(s => s.serviceType === 'mobile');
    const dth = slabs.filter(s => s.serviceType === 'dth');
    const electricity = slabs.filter(s => s.serviceType === 'electricity' || s.serviceType === 'bbps');

    return res.status(200).json({
      success: true,
      data: {
        slabs,
        categories: {
          mobile,
          dth,
          electricity,
        },
      },
    });
  } catch (error) {
    console.error('[getBenefits Error]:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

const UserPlanCache = require('../models/UserPlanCache');
const planApiService = require('../services/planapi.service');

/**
 * GET /api/personal/last-recharge
 * Personal Home Plan & Last Recharge evaluator:
 * CASE 1: Valid active plan information is available -> hasActivePlan: true
 * CASE 2: Successful recent recharge exists, active validity info unavailable -> hasLastRecharge: true
 * CASE 3 & 4: PlanAPI checked where supported (Airtel/VI), fallback to A1 Recharge history for unsupported operators
 * CASE 5: User has zero recharges -> hasActivePlan: false, hasLastRecharge: false ("No active plan yet")
 */
const getLastRecharge = async (req, res) => {
  try {
    const userId = req.user._id;
    const rawPhone = (req.user && (req.user.phone || req.user.mobileNumber || req.user.mobile))
      ? String(req.user.phone || req.user.mobileNumber || req.user.mobile).replace('+91', '').trim()
      : '';

    // ── PRIORITY 1: ACTIVE PENDING TRANSACTION ──
    const pendingTxn = await RechargeTransaction.findOne({ userId, status: 'PENDING' })
      .sort({ createdAt: -1 })
      .lean();

    if (pendingTxn) {
      console.log('[PERSONAL PLAN]', JSON.stringify({
        userId,
        operator: pendingTxn.internalOperatorName || pendingTxn.operatorCode,
        transactionFound: true,
        lastRechargeFound: false,
        planFound: false,
        planSource: 'pending_transaction',
        expiryAvailable: false,
      }));

      return res.status(200).json({
        success: true,
        hasActivePlan: false,
        hasLastRecharge: false,
        isPending: true,
        data: {
          cardType: 'PENDING',
          title: 'Recharge in Progress',
          id: pendingTxn._id,
          orderId: pendingTxn.orderId,
          mobileNumber: pendingTxn.mobileNumber,
          operatorName: pendingTxn.internalOperatorName || pendingTxn.operatorCode,
          operatorCode: pendingTxn.operatorCode,
          circleCode: pendingTxn.circleCode,
          amount: pendingTxn.amount,
          payableAmount: pendingTxn.payableAmount || pendingTxn.amount,
          status: 'PENDING',
          createdAt: pendingTxn.createdAt,
        },
      });
    }

    // ── QUERY MOST RECENT RECHARGE TRANSACTION ──
    const mostRecentTxn = await RechargeTransaction.findOne({ userId })
      .sort({ createdAt: -1 })
      .lean();

    // ── PRIORITY 2: FAILED TRANSACTION ──
    if (mostRecentTxn && mostRecentTxn.status === 'FAILED') {
      console.log('[PERSONAL PLAN]', JSON.stringify({
        userId,
        operator: mostRecentTxn.internalOperatorName || mostRecentTxn.operatorCode,
        transactionFound: true,
        lastRechargeFound: false,
        planFound: false,
        planSource: 'failed_transaction',
        expiryAvailable: false,
      }));

      return res.status(200).json({
        success: true,
        hasActivePlan: false,
        hasLastRecharge: false,
        isFailed: true,
        data: {
          cardType: 'FAILED',
          title: 'Recharge Failed',
          id: mostRecentTxn._id,
          orderId: mostRecentTxn.orderId,
          mobileNumber: mostRecentTxn.mobileNumber,
          operatorName: mostRecentTxn.internalOperatorName || mostRecentTxn.operatorCode,
          operatorCode: mostRecentTxn.operatorCode,
          circleCode: mostRecentTxn.circleCode,
          amount: mostRecentTxn.amount,
          payableAmount: mostRecentTxn.payableAmount || mostRecentTxn.amount,
          status: 'FAILED',
          failureReason: mostRecentTxn.failureReason || 'Provider processing error',
          createdAt: mostRecentTxn.createdAt,
        },
      });
    }

    // ── QUERY RECENT SUCCESSFUL RECHARGE ──
    const latestSuccessTxn = await RechargeTransaction.findOne({ userId, status: 'SUCCESS' })
      .sort({ createdAt: -1 })
      .lean();

    const targetMobile = (latestSuccessTxn && latestSuccessTxn.mobileNumber) ? latestSuccessTxn.mobileNumber : rawPhone;
    let targetOperator = (latestSuccessTxn && latestSuccessTxn.operatorCode) ? latestSuccessTxn.operatorCode : 'AT';

    // ── CHECK 24-HOUR PERSISTENT USER PLAN CACHE FIRST ──
    if (rawPhone) {
      const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;
      let planCache = await UserPlanCache.findOne({ userId, mobileNumber: rawPhone });
      const isCacheValid = planCache && (Date.now() - new Date(planCache.fetchedAt).getTime() < TWENTY_FOUR_HOURS_MS);

      if (planCache && isCacheValid && (planCache.expiryDate || planCache.validity)) {
        const expDate = planCache.expiryDate ? new Date(planCache.expiryDate) : null;
        let daysRem = planCache.daysRemaining;
        if (expDate && !isNaN(expDate.getTime())) {
          daysRem = Math.ceil((expDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
        }

        let colorState = 'GREEN';
        let title = 'Your Plan';
        if (daysRem !== null && daysRem !== undefined) {
          if (daysRem < 0) {
            colorState = 'EXPIRED';
            title = 'Plan Expired';
          } else if (daysRem <= 2) {
            colorState = 'RED';
          } else if (daysRem <= 7) {
            colorState = 'AMBER';
          } else {
            colorState = 'GREEN';
          }
        }

        console.log('[PERSONAL PLAN]', JSON.stringify({
          userId,
          operator: planCache.operatorName || targetOperator,
          transactionFound: !!mostRecentTxn,
          lastRechargeFound: !!latestSuccessTxn,
          planFound: true,
          planSource: 'user_plan_cache',
          expiryAvailable: !!expDate,
        }));

        return res.status(200).json({
          success: true,
          hasActivePlan: true,
          hasLastRecharge: !!latestSuccessTxn,
          source: 'user_plan_cache',
          operator: planCache.operatorName || targetOperator,
          operatorCode: planCache.operatorCode || targetOperator,
          mobileNumber: rawPhone,
          validity: planCache.validity || (expDate ? `${daysRem} days remaining` : 'Active Plan'),
          expiryDate: expDate ? expDate.toISOString() : null,
          daysRemaining: daysRem,
          data: {
            cardType: 'PLAN_STATUS',
            title,
            mobileNumber: rawPhone,
            operatorName: planCache.operatorName || targetOperator,
            operatorCode: planCache.operatorCode || targetOperator,
            validity: planCache.validity || (expDate ? `${daysRem} days remaining` : 'Active Plan'),
            expiryDate: expDate ? expDate.toISOString() : null,
            daysRemaining: daysRem,
            colorState,
          },
        });
      }
    }

    // Check PlanAPI for active plan/expiry details if operator is supported (Airtel/VI)
    let planApiData = null;
    let planExpiryData = null;

    // If no past recharge transaction, attempt operator detection via PlanAPI for rawPhone
    if (!latestSuccessTxn && targetMobile) {
      try {
        const detectRes = await planApiService.detectMobileOperator(targetMobile);
        if (detectRes && detectRes.success && detectRes.data) {
          const rawOpName = (detectRes.data.Operator || detectRes.data.operator || detectRes.data.OperatorName || '').toUpperCase();
          if (rawOpName.includes('AIRTEL')) targetOperator = 'AT';
          else if (rawOpName.includes('JIO') || rawOpName.includes('RELIANCE')) targetOperator = 'JO';
          else if (rawOpName.includes('VI') || rawOpName.includes('VODAFONE') || rawOpName.includes('IDEA')) targetOperator = 'VI';
          else if (rawOpName.includes('BSNL')) targetOperator = 'BT';
        }
      } catch (e) {
        console.log('[PERSONAL PLAN] Auto-detect operator failed:', e.message);
      }
    }

    if (targetMobile && planApiService.isOperatorSupportedForLastRechargeAndExpiry(targetOperator)) {
      try {
        const [lastRes, expRes] = await Promise.all([
          planApiService.checkLastRecharge(targetMobile, targetOperator),
          planApiService.checkRechargeExpiry(targetMobile, targetOperator),
        ]);
        if (lastRes && lastRes.success) planApiData = lastRes.data;
        if (expRes && expRes.success) planExpiryData = expRes.data;
      } catch (err) {
        console.log('[PlanAPI Check Error]:', err.message);
      }
    }

    // CASE 1: Active plan info available from PlanAPI or verified validity
    const hasActivePlanData = !!(planExpiryData && (planExpiryData.outgoing || planExpiryData.incoming));

    // Check 24-hour persistent UserPlanCache if live PlanAPI response is empty
    if (!hasActivePlanData && rawPhone) {
      const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;
      let planCache = await UserPlanCache.findOne({ userId, mobileNumber: rawPhone });
      const isCacheValid = planCache && (Date.now() - new Date(planCache.fetchedAt).getTime() < TWENTY_FOUR_HOURS_MS);

      if (planCache && (planCache.expiryDate || planCache.validity)) {
        const expDate = planCache.expiryDate ? new Date(planCache.expiryDate) : null;
        let daysRem = planCache.daysRemaining;
        if (expDate && !isNaN(expDate.getTime())) {
          daysRem = Math.ceil((expDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
        }

        let colorState = 'GREEN';
        let title = 'Your Plan';
        if (daysRem !== null && daysRem !== undefined) {
          if (daysRem < 0) {
            colorState = 'EXPIRED';
            title = 'Plan Expired';
          } else if (daysRem <= 2) {
            colorState = 'RED';
          } else if (daysRem <= 7) {
            colorState = 'AMBER';
          } else {
            colorState = 'GREEN';
          }
        }

        console.log('[PERSONAL PLAN]', JSON.stringify({
          userId,
          operator: planCache.operatorName || targetOperator,
          transactionFound: !!mostRecentTxn,
          lastRechargeFound: !!latestSuccessTxn,
          planFound: true,
          planSource: 'user_plan_cache',
          expiryAvailable: !!expDate,
        }));

        return res.status(200).json({
          success: true,
          hasActivePlan: true,
          hasLastRecharge: !!latestSuccessTxn,
          source: 'user_plan_cache',
          operator: planCache.operatorName || targetOperator,
          operatorCode: planCache.operatorCode || targetOperator,
          mobileNumber: rawPhone,
          validity: planCache.validity || (expDate ? `${daysRem} days remaining` : 'Active Plan'),
          expiryDate: expDate ? expDate.toISOString() : null,
          daysRemaining: daysRem,
          data: {
            cardType: 'PLAN_STATUS',
            title,
            mobileNumber: rawPhone,
            operatorName: planCache.operatorName || targetOperator,
            operatorCode: planCache.operatorCode || targetOperator,
            validity: planCache.validity || (expDate ? `${daysRem} days remaining` : 'Active Plan'),
            expiryDate: expDate ? expDate.toISOString() : null,
            daysRemaining: daysRem,
            colorState,
          },
        });
      }
    }

    if (hasActivePlanData) {
      console.log('[PERSONAL PLAN]', JSON.stringify({
        userId,
        operator: targetOperator,
        transactionFound: !!mostRecentTxn,
        lastRechargeFound: !!latestSuccessTxn,
        planFound: true,
        planSource: 'planapi',
        expiryAvailable: true,
      }));

      return res.status(200).json({
        success: true,
        hasActivePlan: true,
        hasLastRecharge: !!latestSuccessTxn,
        source: 'planapi',
        operator: (latestSuccessTxn && latestSuccessTxn.internalOperatorName) || targetOperator,
        operatorCode: targetOperator,
        mobileNumber: targetMobile,
        amount: planApiData ? (Number(planApiData.amount) || (latestSuccessTxn ? latestSuccessTxn.amount : 0)) : (latestSuccessTxn ? latestSuccessTxn.amount : 0),
        rechargeDate: planApiData ? planApiData.rechargeDate : (latestSuccessTxn ? latestSuccessTxn.createdAt : null),
        validity: planExpiryData ? `Outgoing: ${planExpiryData.outgoing}` : 'Active',
        expiryDate: planExpiryData ? planExpiryData.outgoing : null,
        outgoing: planExpiryData ? planExpiryData.outgoing : null,
        incoming: planExpiryData ? planExpiryData.incoming : null,
        data: {
          cardType: 'PLAN_STATUS',
          title: 'Your Plan',
          mobileNumber: targetMobile,
          operatorName: (latestSuccessTxn && latestSuccessTxn.internalOperatorName) || targetOperator,
          operatorCode: targetOperator,
          amount: (latestSuccessTxn && latestSuccessTxn.amount) || 0,
          validity: planExpiryData ? `Valid until ${planExpiryData.outgoing}` : 'Active Plan',
          expiryDate: planExpiryData ? planExpiryData.outgoing : null,
          outgoing: planExpiryData ? planExpiryData.outgoing : null,
          incoming: planExpiryData ? planExpiryData.incoming : null,
          colorState: 'GREEN',
        },
      });
    }

    // CASE 2 & CASE 4: Successful recent recharge exists (fallback to A1 Recharge history for unsupported operators or missing expiry)
    if (latestSuccessTxn) {
      console.log('[PERSONAL PLAN]', JSON.stringify({
        userId,
        operator: latestSuccessTxn.internalOperatorName || latestSuccessTxn.operatorCode,
        transactionFound: true,
        lastRechargeFound: true,
        planFound: false,
        planSource: 'a1_recharge',
        expiryAvailable: false,
      }));

      return res.status(200).json({
        success: true,
        hasActivePlan: false,
        hasLastRecharge: true,
        source: 'a1_recharge',
        lastRecharge: {
          id: latestSuccessTxn._id,
          orderId: latestSuccessTxn.orderId,
          operator: latestSuccessTxn.internalOperatorName || latestSuccessTxn.operatorCode,
          operatorCode: latestSuccessTxn.operatorCode,
          mobileNumber: latestSuccessTxn.mobileNumber,
          amount: latestSuccessTxn.amount,
          payableAmount: latestSuccessTxn.payableAmount || latestSuccessTxn.amount,
          savingsAmount: latestSuccessTxn.commissionAmount || 0,
          status: 'SUCCESS',
          date: latestSuccessTxn.createdAt,
        },
        data: {
          cardType: 'SUCCESS',
          title: 'Your Last Recharge',
          id: latestSuccessTxn._id,
          orderId: latestSuccessTxn.orderId,
          mobileNumber: latestSuccessTxn.mobileNumber,
          operatorName: latestSuccessTxn.internalOperatorName || latestSuccessTxn.operatorCode,
          operatorCode: latestSuccessTxn.operatorCode,
          circleCode: latestSuccessTxn.circleCode,
          amount: latestSuccessTxn.amount,
          payableAmount: latestSuccessTxn.payableAmount || latestSuccessTxn.amount,
          savingsAmount: latestSuccessTxn.commissionAmount || 0,
          status: 'SUCCESS',
          createdAt: latestSuccessTxn.createdAt,
        },
      });
    }

    // CASE 5: User has never completed a recharge -> "No active plan yet"
    console.log('[PERSONAL PLAN]', JSON.stringify({
      userId,
      operator: 'none',
      transactionFound: false,
      lastRechargeFound: false,
      planFound: false,
      planSource: 'none',
      expiryAvailable: false,
    }));

    return res.status(200).json({
      success: true,
      hasActivePlan: false,
      hasLastRecharge: false,
      data: {
        cardType: 'NO_PLAN',
        title: 'Your Plan',
        statusText: 'No active plan yet',
      },
    });
  } catch (error) {
    console.error('[getLastRecharge Error]:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/personal/recent-transactions
 * Returns top 3 recent transactions
 */
const getRecentTransactions = async (req, res) => {
  try {
    const userId = req.user._id;
    const transactions = await RechargeTransaction.find({ userId })
      .sort({ createdAt: -1 })
      .limit(3)
      .lean();

    const formatted = transactions.map(txn => ({
      id: txn._id,
      orderId: txn.orderId,
      mobileNumber: txn.mobileNumber,
      operatorName: txn.internalOperatorName || txn.operatorCode,
      serviceType: txn.serviceType || 'mobile',
      amount: txn.amount,
      payableAmount: txn.payableAmount || txn.amount,
      savingsAmount: txn.commissionAmount || 0,
      status: txn.status,
      createdAt: txn.createdAt,
    }));

    return res.status(200).json({ success: true, data: formatted });
  } catch (error) {
    console.error('[getRecentTransactions Error]:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/personal/frequent-numbers
 * Returns top 5 frequently recharged numbers from history
 */
const getFrequentNumbers = async (req, res) => {
  try {
    const userId = req.user._id;

    const aggregate = await RechargeTransaction.aggregate([
      { $match: { userId: new mongoose.Types.ObjectId(userId), status: 'SUCCESS' } },
      {
        $group: {
          _id: '$mobileNumber',
          operatorName: { $last: '$internalOperatorName' },
          operatorCode: { $last: '$operatorCode' },
          lastRechargeAmount: { $last: '$amount' },
          lastRechargeDate: { $last: '$createdAt' },
          count: { $sum: 1 },
        },
      },
      { $sort: { count: -1, lastRechargeDate: -1 } },
      { $limit: 5 },
    ]);

    const formatted = aggregate.map(item => ({
      mobileNumber: item._id,
      operatorName: item.operatorName || item.operatorCode || 'Operator',
      operatorCode: item.operatorCode,
      lastRechargeAmount: item.lastRechargeAmount,
      count: item.count,
    }));

    return res.status(200).json({ success: true, data: formatted });
  } catch (error) {
    console.error('[getFrequentNumbers Error]:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/personal/last-successful
 * Returns strictly the customer's most recent SUCCESSFUL recharge transaction.
 * Ignores PENDING, FAILED, and CANCELLED transactions.
 */
const getLastSuccessfulRecharge = async (req, res) => {
  try {
    const userId = req.user._id;

    const latestSuccessTxn = await RechargeTransaction.findOne({ userId, status: 'SUCCESS' })
      .sort({ createdAt: -1 })
      .lean();

    if (!latestSuccessTxn) {
      return res.status(200).json({
        success: true,
        hasLastSuccessful: false,
        data: null,
      });
    }

    return res.status(200).json({
      success: true,
      hasLastSuccessful: true,
      data: {
        id: latestSuccessTxn._id,
        orderId: latestSuccessTxn.orderId,
        amount: latestSuccessTxn.amount,
        mobileNumber: latestSuccessTxn.mobileNumber,
        operator: latestSuccessTxn.internalOperatorName || latestSuccessTxn.operatorCode,
        operatorCode: latestSuccessTxn.operatorCode,
        circleCode: latestSuccessTxn.circleCode,
        status: 'SUCCESS',
        rechargeDate: latestSuccessTxn.createdAt,
      },
    });
  } catch (error) {
    console.error('[getLastSuccessfulRecharge Error]:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getSavings,
  getBenefits,
  getLastRecharge,
  getLastSuccessfulRecharge,
  getRecentTransactions,
  getFrequentNumbers,
};
