const mongoose = require('mongoose');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
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
    const userIds = [userId];
    if (userId && typeof userId.toString === 'function') {
      userIds.push(userId.toString());
    }

    const now = new Date();
    const startOfCurrentMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfPrevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const endOfPrevMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);

    // Fetch all SUCCESS transactions for user
    const transactions = await RechargeTransaction.find({
      userId: { $in: userIds },
      status: { $in: ['SUCCESS', 'success', 'COMPLETED', 'completed'] },
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

    console.log('\n[SAVINGS DEBUG]');
    console.log(`userId: ${userId.toString()}`);
    console.log(`currentMonth: ${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`);
    console.log(`successfulEligibleTransactions: ${transactions.length}`);
    for (const txn of transactions) {
      console.log(`  ${txn.providerTransactionId || txn.orderId} -> ₹${(txn.commissionAmount || 0).toFixed(2)}`);
    }
    console.log(`totalSavings: ₹${Number(lifetimeSavings.toFixed(2))}\n`);

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

function inferServiceType(doc) {
  if (doc.serviceType && doc.serviceType !== 'undefined') return String(doc.serviceType).toLowerCase().trim();
  const code = String(doc.operatorCode || '').toUpperCase().trim();
  const name = String(doc.operatorName || '').toLowerCase().trim();

  if (['TP', 'TTV', 'DISH', 'DTV', 'SUN', 'STV', 'AIRDTH', 'ATV', 'VTV', 'DA'].includes(code) || 
      name.includes('dth') || name.includes('tata sky') || name.includes('tata play') || 
      name.includes('dish tv') || name.includes('sun direct') || name.includes('videocon')) {
    return 'dth';
  }
  if (['BESCOM', 'TSSPDCL', 'TGSPDCL'].includes(code) || name.includes('electricity')) {
    return 'electricity';
  }
  if (['IGAS'].includes(code) || name.includes('gas')) {
    return 'gas';
  }
  if (['PFAST'].includes(code) || name.includes('fastag')) {
    return 'fastag';
  }
  return 'mobile';
}

function getCanonicalOperatorCode(rawCode, rawName, serviceType) {
  const code = String(rawCode || '').toUpperCase().trim();
  const name = String(rawName || '').toLowerCase().replace(/[^a-z0-9]/g, '');
  const service = String(serviceType || 'mobile').toLowerCase().trim();

  if (service === 'mobile') {
    if (['A', 'AT', 'AIRTEL'].includes(code) || name.includes('airtel')) return 'AT';
    if (['RC', 'JO', 'JIO'].includes(code) || name.includes('jio') || name.includes('reliance')) return 'JO';
    if (['V', 'VI', 'VODAFONE', 'I', 'IDEA'].includes(code) || name.includes('vi') || name.includes('vodafone') || name.includes('idea')) return 'VI';
    if (['BR', 'BSNL'].includes(code) && !name.includes('stv') && !name.includes('special')) return 'BR';
    if (['BT'].includes(code) || name.includes('stv') || name.includes('special')) return 'BT';
  } else if (service === 'dth') {
    if (['AIRDTH', 'ATV', 'DA'].includes(code) || name.includes('airteldth') || name.includes('airtel dth')) return 'AIRDTH';
    if (['TP', 'TTV'].includes(code) || name.includes('tataplay') || name.includes('tatasky') || name.includes('tata sky')) return 'TP';
    if (['DISH', 'DTV'].includes(code) || name.includes('dishtv') || name.includes('dish tv')) return 'DISH';
    if (['SUN', 'STV'].includes(code) || name.includes('sundirect') || name.includes('sun direct')) return 'SUN';
    if (['VTV'].includes(code) || name.includes('videocon') || name.includes('d2h')) return 'VTV';
  }

  return code || name;
}

/**
 * GET /api/personal/benefits
 * Returns active personal benefit slabs grouped by service type
 */
const getBenefits = async (req, res) => {
  try {
    const userAccountType = (req.user && req.user.accountType) ? String(req.user.accountType).toUpperCase() : 'PERSONAL';
    const reqCategory = (req.query.category || req.query.serviceType || '').toLowerCase().trim();

    let rawSlabs = await OperatorCommission.find({ accountType: userAccountType === 'BUSINESS' ? 'BUSINESS' : 'PERSONAL', status: 'ACTIVE' })
      .sort({ serviceType: 1, operatorName: 1 })
      .lean();

    if (rawSlabs.length === 0) {
      const fallbackSlabs = await PersonalCommissionSlab.find({ status: 'ACTIVE' }).lean();
      rawSlabs = fallbackSlabs.map((s) => ({
        accountType: 'PERSONAL',
        operatorCode: s.operatorCode,
        operatorName: s.operatorName,
        serviceType: s.serviceType,
        commissionType: s.commissionType || 'percentage',
        commissionValue: s.commissionValue || 0.8,
        personalCommission: s.commissionValue || 0.8,
        status: s.status,
      }));
    }

    console.log(`[BENEFITS API] RAW RATE COUNT: ${rawSlabs.length} for accountType=${userAccountType}`);
    for (const s of rawSlabs) {
      console.log(`[BENEFITS API] RATE: operatorId=${s._id} operatorCode=${s.operatorCode} operatorName=${s.operatorName} accountType=${s.accountType} category=${s.serviceType} personalCommission=${s.personalCommission} retailerCommission=${s.retailerCommission}`);
    }

    // Map slabs per accountType + service category + operatorCode
    const uniqueMap = new Map();
    for (const s of rawSlabs) {
      const service = inferServiceType(s);
      const code = (s.operatorCode || '').toUpperCase().trim();
      const name = (s.operatorName || '').trim();

      // Composite key per accountType + serviceType + operatorCode
      const compositeKey = `${userAccountType}_${service}_${code}`;

      const commVal = (userAccountType === 'BUSINESS')
        ? (s.retailerCommission ?? s.personalCommission ?? 0.8)
        : (s.personalCommission ?? s.retailerCommission ?? 0.8);

      const formattedSlab = {
        id: s._id ? s._id.toString() : compositeKey,
        accountType: s.accountType || userAccountType,
        operatorCode: code,
        operatorName: name || code,
        serviceType: service,
        commissionType: s.commissionType || 'percentage',
        commissionValue: Number(commVal),
        personalCommission: s.personalCommission ?? commVal,
        retailerCommission: s.retailerCommission ?? commVal,
        providerCommission: s.providerCommission ?? 0,
        status: s.status || 'ACTIVE',
      };

      if (!uniqueMap.has(compositeKey)) {
        uniqueMap.set(compositeKey, formattedSlab);
      } else {
        uniqueMap.set(compositeKey, formattedSlab);
      }
    }

    const slabs = Array.from(uniqueMap.values());
    console.log(`[BENEFITS API] FINAL DEDUPLICATED RATE COUNT: ${slabs.length}`);

    const mobile = slabs.filter(s => s.serviceType === 'mobile');
    const dth = slabs.filter(s => s.serviceType === 'dth');
    const electricity = slabs.filter(s => s.serviceType === 'electricity' || s.serviceType === 'bbps');
    const gas = slabs.filter(s => s.serviceType === 'gas');
    const fastag = slabs.filter(s => s.serviceType === 'fastag');

    let filteredSlabs = slabs;
    if (reqCategory === 'mobile') filteredSlabs = mobile;
    else if (reqCategory === 'dth') filteredSlabs = dth;
    else if (reqCategory === 'electricity' || reqCategory === 'bbps') filteredSlabs = electricity;
    else if (reqCategory === 'gas') filteredSlabs = gas;
    else if (reqCategory === 'fastag') filteredSlabs = fastag;

    return res.status(200).json({
      success: true,
      data: {
        accountType: userAccountType,
        slabs: filteredSlabs,
        allSlabs: slabs,
        categories: {
          mobile,
          dth,
          electricity,
          gas,
          fastag,
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
/**
 * GET /api/personal/last-recharge
 * Strictly returns the customer's most recent SUCCESSFUL recharge transaction.
 * Does NOT query PlanAPI or UserPlanCache.
 * Ignores PENDING, FAILED, and non-terminal transactions.
 */
const getLastRecharge = async (req, res) => {
  try {
    const userId = req.user._id;
    const userIds = [userId];
    if (userId && typeof userId.toString === 'function') {
      userIds.push(userId.toString());
    }

    // Query most recent SUCCESSFUL recharge transaction
    const latestSuccessTxn = await RechargeTransaction.findOne({
      userId: { $in: userIds },
      status: { $in: ['SUCCESS', 'success', 'COMPLETED', 'completed'] },
    })
      .sort({ completedAt: -1, createdAt: -1 })
      .lean();

    if (!latestSuccessTxn) {
      return res.status(200).json({
        success: true,
        hasLastRecharge: false,
        data: null,
      });
    }

    // Infer recharge label / category (Top-up, Data Recharge, Mobile Recharge, etc.)
    let rechargeType = 'Mobile Recharge';
    const rawType = String(latestSuccessTxn.planType || '').toUpperCase().trim();
    const rawName = String(latestSuccessTxn.planName || '').toLowerCase().trim();
    const amount = Number(latestSuccessTxn.amount || 0);

    if (rawType === 'TOPUP' || rawType === 'TALKTIME' || rawName.includes('topup') || rawName.includes('top-up') || amount <= 50) {
      rechargeType = 'Top-up';
    } else if (rawType === 'DATA' || rawName.includes('data') || rawName.includes('4g') || rawName.includes('5g')) {
      rechargeType = 'Data Recharge';
    } else if (latestSuccessTxn.planName) {
      rechargeType = latestSuccessTxn.planName;
    }

    return res.status(200).json({
      success: true,
      hasLastRecharge: true,
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
        rechargeType,
        status: 'SUCCESS',
        createdAt: latestSuccessTxn.createdAt,
      },
    });
  } catch (error) {
    console.error('[getLastRecharge Error]:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/personal/pending-recharge
 * Returns any in-flight pending or processing recharge transaction for the user.
 */
const getPendingRecharge = async (req, res) => {
  try {
    const userId = req.user._id;
    const userIds = [userId];
    if (userId && typeof userId.toString === 'function') {
      userIds.push(userId.toString());
    }

    const pendingTxn = await RechargeTransaction.findOne({
      userId: { $in: userIds },
      status: { $in: ['PENDING', 'pending', 'PROCESSING', 'processing', 'RECHARGE_PROCESSING', 'recharge_processing', 'INITIATED', 'initiated'] },
    })
      .sort({ createdAt: -1 })
      .lean();

    if (!pendingTxn) {
      return res.status(200).json({
        success: true,
        hasPending: false,
        data: null,
      });
    }

    return res.status(200).json({
      success: true,
      hasPending: true,
      data: {
        cardType: 'PENDING',
        title: 'Recharge in Progress',
        id: pendingTxn._id,
        orderId: pendingTxn.orderId,
        mobileNumber: pendingTxn.mobileNumber,
        operatorName: pendingTxn.internalOperatorName || pendingTxn.operatorCode,
        operatorCode: pendingTxn.operatorCode,
        amount: pendingTxn.amount,
        payableAmount: pendingTxn.payableAmount || pendingTxn.amount,
        status: pendingTxn.status,
        createdAt: pendingTxn.createdAt,
      },
    });
  } catch (error) {
    console.error('[getPendingRecharge Error]:', error);
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

/**
 * GET /api/personal/current-plan
 * Evaluates strictly whether the user has an active/current Monthly or Yearly plan.
 * Top-ups (₹10, ₹20, ₹50), talktime vouchers, data vouchers are NEVER returned as current plans.
 */
const getCurrentPlan = async (req, res) => {
  try {
    const userId = req.user._id;
    const userIds = [userId];
    if (userId && typeof userId.toString === 'function') {
      userIds.push(userId.toString());
    }

    const rawPhone = (req.user && (req.user.phone || req.user.mobileNumber || req.user.mobile))
      ? String(req.user.phone || req.user.mobileNumber || req.user.mobile).replace('+91', '').trim()
      : '';

    const isMonthlyOrYearlyPlan = (txn) => {
      if (!txn) return false;
      const pType = String(txn.planType || '').toUpperCase().trim();
      const name = String(txn.planName || '').toUpperCase().trim();
      const category = String(txn.selectedCategory || '').toUpperCase().trim();
      const amount = Number(txn.amount || 0);

      if (pType === 'TOPUP' || pType === 'TALKTIME' || category.includes('TOPUP') || category.includes('TALKTIME')) {
        return false;
      }
      if (amount <= 50) return false;
      if (pType === 'MONTHLY' || pType === 'YEARLY' || pType === 'UNLIMITED' || pType === 'PLAN' || pType === 'STV') {
        return true;
      }
      if (name.includes('VALIDITY') || name.includes('MONTH') || name.includes('YEAR') || name.includes('DAYS') || name.includes('UNLIMITED')) {
        return true;
      }
      return amount >= 100;
    };

    const pendingPlanTxn = await RechargeTransaction.findOne({
      userId: { $in: userIds },
      status: 'PENDING',
    }).sort({ createdAt: -1 }).lean();

    if (pendingPlanTxn && isMonthlyOrYearlyPlan(pendingPlanTxn)) {
      return res.status(200).json({
        success: true,
        hasActivePlan: true,
        isPending: true,
        data: {
          title: 'Recharge in Progress',
          operatorName: pendingPlanTxn.internalOperatorName || pendingPlanTxn.operatorCode,
          operatorCode: pendingPlanTxn.operatorCode,
          mobileNumber: pendingPlanTxn.mobileNumber,
          amount: pendingPlanTxn.amount,
          validity: 'Processing...',
          daysRemaining: null,
          status: 'PENDING',
          colorState: 'AMBER',
        },
      });
    }

    if (rawPhone) {
      const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;
      let planCache = await UserPlanCache.findOne({ userId: { $in: userIds }, mobileNumber: rawPhone });

      // Helper to find latest monthly/yearly plan transaction amount
      const latestMonthlyTxn = await RechargeTransaction.findOne({
        userId: { $in: userIds },
        status: { $in: ['SUCCESS', 'success'] },
        amount: { $gte: 100 },
      }).sort({ createdAt: -1 }).lean();

      const planAmount = (planCache && planCache.amount) || (latestMonthlyTxn ? latestMonthlyTxn.amount : 0);
      const isCacheValid = planCache && (Date.now() - new Date(planCache.fetchedAt).getTime() < TWENTY_FOUR_HOURS_MS) && Boolean(planCache.amount && planCache.amount > 0);

      if (planCache && isCacheValid && (planCache.expiryDate || planCache.validity)) {
        const expDate = planCache.expiryDate ? new Date(planCache.expiryDate) : null;
        let daysRem = planCache.daysRemaining;
        if (expDate && !isNaN(expDate.getTime())) {
          daysRem = Math.ceil((expDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
        }

        let colorState = 'GREEN';
        let title = 'Your Current Plan';
        if (daysRem !== null && daysRem !== undefined) {
          if (daysRem < 0) {
            colorState = 'EXPIRED';
            title = 'Plan Expired';
          } else if (daysRem <= 2) {
            colorState = 'RED';
          } else if (daysRem <= 7) {
            colorState = 'AMBER';
          }
        }

        let displayOp = planCache.operatorName || 'Airtel';
        if (displayOp === '2' || displayOp === 'AT') displayOp = 'Airtel';
        else if (displayOp === '11' || displayOp === 'JO') displayOp = 'Jio';
        else if (displayOp === '23' || displayOp === '6' || displayOp === 'VI') displayOp = 'VI';
        else if (displayOp === '4' || displayOp === '5' || displayOp === 'BT') displayOp = 'BSNL';

        return res.status(200).json({
          success: true,
          hasActivePlan: true,
          source: 'planapi_cache',
          data: {
            title,
            mobileNumber: rawPhone,
            operatorName: displayOp,
            operatorCode: planCache.operatorCode || '',
            amount: planAmount,
            validity: planCache.validity || (expDate ? `${daysRem} days remaining` : 'Active Plan'),
            expiryDate: expDate ? expDate.toISOString() : null,
            daysRemaining: daysRem,
            colorState,
          },
        });
      }

      // Query live Plans API for recharge expiry date and last recharge plan amount
      try {
        const planApiService = require('../services/planapi.service');
        const opRes = await planApiService.detectMobileOperator(rawPhone);
        const rawOpName = opRes.success && opRes.data ? (opRes.data.Operator || opRes.data.operator || 'Airtel') : 'Airtel';
        const opCode = opRes.success && opRes.data ? (opRes.data.OpCode || opRes.data.OperatorCode || opRes.data.operator_code || '2') : '2';

        const [lastRecRes, expRes] = await Promise.all([
          planApiService.checkLastRecharge(rawPhone, opCode).catch(() => ({ success: false })),
          planApiService.checkRechargeExpiry(rawPhone, opCode).catch(() => ({ success: false })),
        ]);

        console.log('[CURRENT_PLAN_DEBUG] Plans API response:', JSON.stringify({
          mobile: rawPhone,
          operator: rawOpName,
          lastRechargeResponse: lastRecRes,
          expiryResponse: expRes,
        }, null, 2));

        const liveAmount = Number(lastRecRes?.data?.amount || lastRecRes?.data?.raw?.Amount || 0) || planAmount;

        if ((expRes.supported && expRes.success && expRes.data && expRes.data.outgoing) || liveAmount > 0) {
          const expDate = (expRes.data && expRes.data.outgoing) ? new Date(expRes.data.outgoing) : null;
          let daysRem = null;
          if (expDate && !isNaN(expDate.getTime())) {
            daysRem = Math.ceil((expDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
          }

          let colorState = 'GREEN';
          let title = 'Your Current Plan';
          if (daysRem !== null && daysRem !== undefined) {
            if (daysRem < 0) {
              colorState = 'EXPIRED';
              title = 'Plan Expired';
            } else if (daysRem <= 2) {
              colorState = 'RED';
            } else if (daysRem <= 7) {
              colorState = 'AMBER';
            }
          }

          const validityText = daysRem !== null ? `${daysRem} days remaining` : 'Active Plan';

          await UserPlanCache.findOneAndUpdate(
            { userId: userId, mobileNumber: rawPhone },
            {
              userId: userId,
              mobileNumber: rawPhone,
              operatorName: rawOpName,
              operatorCode: opCode,
              amount: liveAmount,
              validity: validityText,
              expiryDate: expDate,
              daysRemaining: daysRem,
              colorState,
              fetchedAt: new Date(),
            },
            { upsert: true, returnDocument: 'after' }
          );

          return res.status(200).json({
            success: true,
            hasActivePlan: true,
            source: 'planapi',
            data: {
              title,
              mobileNumber: rawPhone,
              operatorName: rawOpName,
              operatorCode: opCode,
              amount: liveAmount,
              validity: validityText,
              expiryDate: expDate ? expDate.toISOString() : null,
              daysRemaining: daysRem,
              colorState,
            },
          });
        }
      } catch (err) {
        console.log('[getCurrentPlan PlansAPI Fetch Warning]:', err.message);
      }
    }

    const latestSuccessPlanTxn = await RechargeTransaction.findOne({
      userId: { $in: userIds },
      status: 'SUCCESS',
    }).sort({ createdAt: -1 }).lean();

    if (latestSuccessPlanTxn && isMonthlyOrYearlyPlan(latestSuccessPlanTxn)) {
      return res.status(200).json({
        success: true,
        hasActivePlan: true,
        data: {
          title: 'Your Current Plan',
          mobileNumber: latestSuccessPlanTxn.mobileNumber,
          operatorName: latestSuccessPlanTxn.internalOperatorName || latestSuccessPlanTxn.operatorCode,
          operatorCode: latestSuccessPlanTxn.operatorCode,
          amount: latestSuccessPlanTxn.amount,
          validity: latestSuccessPlanTxn.planName || 'Active Plan',
          daysRemaining: null,
          colorState: 'GREEN',
        },
      });
    }

    return res.status(200).json({
      success: true,
      hasActivePlan: false,
      data: null,
    });
  } catch (error) {
    console.error('[getCurrentPlan Error]:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/personal/transactions
 * GET /api/personal/history
 * GET /api/personal/recent-transactions
 * Retrieve full transaction history for Personal Account
 */
const getPersonalTransactions = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, type, days } = req.query;
    const userId = req.user._id;
    const userIds = [userId];
    if (userId && typeof userId.toString === 'function') {
      userIds.push(userId.toString());
    }

    const baseQuery = { userId: { $in: userIds } };

    if (days && !isNaN(Number(days))) {
      const daysNum = Number(days);
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - daysNum);
      baseQuery.createdAt = { $gte: startDate };
    }

    const txQuery = { ...baseQuery };

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
        transactionTitle: t.service === 'admin_credit' ? 'ADMIN CREDIT' : (t.service === 'dth' ? 'DTH Recharge' : 'Mobile Recharge'),
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

    const rechargeTxns = await RechargeTransaction.find(baseQuery)
      .sort({ createdAt: -1 })
      .lean()
      .maxTimeMS(3000);

    const existingRefIds = new Set(formattedGlobal.map(t => t.referenceNumber).filter(Boolean));
    const existingIds = new Set(formattedGlobal.map(t => t.id));

    const formattedRecharges = rechargeTxns
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
          amount: Math.round((r.amount || 0) * 100),
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

    const merged = [...formattedGlobal, ...formattedRecharges];
    merged.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    const pageNum = Number(page) || 1;
    const limitNum = Number(limit) || 20;
    const startIndex = (pageNum - 1) * limitNum;
    const paginated = merged.slice(startIndex, startIndex + limitNum);

    console.log(`[PERSONAL HISTORY DEBUG] userId=${userId} totalMatched=${merged.length} returning=${paginated.length}`);

    return res.status(200).json({
      success: true,
      data: paginated,
      totalCount: merged.length,
      page: pageNum,
      limit: limitNum,
    });
  } catch (error) {
    console.error('[getPersonalTransactions Error]:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getSavings,
  getBenefits,
  getCurrentPlan,
  getLastRecharge,
  getPendingRecharge,
  getLastSuccessfulRecharge,
  getPersonalTransactions,
  getRecentTransactions,
  getFrequentNumbers,
};
