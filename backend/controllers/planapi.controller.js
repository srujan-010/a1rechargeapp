const planApiService = require('../services/planapi.service');
const operatorDetectCache = new Map();
const OPERATOR_CACHE_TTL_MS = 30 * 60 * 1000;

// @desc    Detect Mobile Operator
// @route   GET /api/plans/mobile/operator
// @access  Private
const detectMobileOperator = async (req, res, next) => {
  try {
    const { mobile, force } = req.query;
    if (!mobile) return res.status(400).json({ success: false, message: 'mobile is required' });

    const cleanMobile = String(mobile).replace('+91', '').trim();
    const now = Date.now();

    if (!force && operatorDetectCache.has(cleanMobile)) {
      const cached = operatorDetectCache.get(cleanMobile);
      if (now - cached.timestamp < OPERATOR_CACHE_TTL_MS) {
        console.log(`[PLAN API Cache Hit] Mobile: ${cleanMobile}`);
        return res.status(200).json(cached.result);
      }
    }

    const result = await planApiService.detectMobileOperator(cleanMobile);
    if (result && result.success) {
      operatorDetectCache.set(cleanMobile, { result, timestamp: now });
    }

    res.status(200).json(result);
  } catch (error) {
    console.error('[PlanAPI Proxy Error]', error.message);
    res.status(500).json({ success: false, message: 'Failed to fetch from PlanAPI' });
  }
};

const mongoose = require('mongoose');
const ProviderOperator = require('../models/ProviderOperator');
const { resolvePlansApiOperatorCode } = require('../utils/operatorMapper');

// @desc    Fetch Mobile Plans
// @route   GET /api/plans/mobile/packs
// @access  Private
const fetchMobilePlans = async (req, res, next) => {
  try {
    const { operatorcode, circle, mobile, planType, rechargeType } = req.query;
    if (!operatorcode || !circle) return res.status(400).json({ success: false, message: 'operatorcode and circle are required' });

    const selectedPlanType = (planType || rechargeType || '').toString().toUpperCase().trim();
    let targetOp = operatorcode;

    // Check if operatorcode is a MongoDB ObjectId or operator ID
    if (mongoose.Types.ObjectId.isValid(operatorcode)) {
      const dbOp = await ProviderOperator.findById(operatorcode);
      if (dbOp) {
        targetOp = dbOp;
      }
    } else if (typeof operatorcode === 'string' && operatorcode.trim() !== '') {
      const dbOp = await ProviderOperator.findOne({
        $or: [
          { code: String(operatorcode).trim().toUpperCase() },
          { name: new RegExp(`^${operatorcode.trim()}$`, 'i') }
        ]
      });
      if (dbOp) {
        targetOp = dbOp;
      }
    }

    const plansApiOpCode = resolvePlansApiOperatorCode(targetOp, selectedPlanType);
    const opDisplayName = typeof targetOp === 'object' ? targetOp.name : operatorcode;

    console.log('\n====================================================');
    console.log('[PLAN API OPERATOR MAPPING]');
    console.log(`displayName=${opDisplayName}`);
    console.log(`planType=${selectedPlanType || 'TOPUP'}`);
    console.log(`plansApiOperatorCode=${plansApiOpCode}`);
    console.log('====================================================\n');

    console.log('\n====================================================');
    console.log('[PLAN API REQUEST]');
    console.log(`operatorName=${opDisplayName}`);
    console.log(`planType=${selectedPlanType || 'TOPUP'}`);
    console.log(`plansApiOperatorCode=${plansApiOpCode}`);
    console.log(`circleCode=${circle}`);
    console.log(`mobile=${mobile || 'N/A'}`);
    console.log('====================================================\n');

    const result = await planApiService.fetchMobilePlans(plansApiOpCode, circle);

    console.log('\n====================================================');
    console.log('[PLAN API RESPONSE]');
    if (result && result.data) {
      console.log(`httpStatus=200`);
      console.log(`ERROR=${result.data.ERROR}`);
      console.log(`STATUS=${result.data.STATUS}`);
      console.log(`MESSAGE=${result.data.Message || result.data.MESSAGE || 'N/A'}`);
      console.log(`RDATA=${result.data.RDATA ? (Array.isArray(result.data.RDATA) ? `${result.data.RDATA.length} plans` : (typeof result.data.RDATA === 'object' ? Object.keys(result.data.RDATA).length + ' categories' : 'populated')) : 'null'}`);
    }
    console.log('====================================================\n');

    res.status(200).json(result);
  } catch (error) {
    console.error('[PlanAPI Proxy Error]', error.message);
    res.status(500).json({ success: false, message: 'Failed to fetch from PlanAPI' });
  }
};

// @desc    Detect DTH Operator
// @route   GET /api/plans/dth/operator
// @access  Private
const detectDthOperator = async (req, res, next) => {
  try {
    const { mobile } = req.query;
    if (!mobile) return res.status(400).json({ success: false, message: 'mobile is required' });
    const result = await planApiService.detectDthOperator(mobile);
    res.status(200).json(result);
  } catch (error) {
    console.error('[PlanAPI Proxy Error]', error.message);
    res.status(500).json({ success: false, message: 'Failed to fetch from PlanAPI' });
  }
};

// @desc    Fetch DTH Customer Info
// @route   GET /api/plans/dth/info
// @access  Private
const fetchDthCustomerInfo = async (req, res, next) => {
  try {
    const { mobile, operatorcode } = req.query;
    if (!mobile || !operatorcode) return res.status(400).json({ success: false, message: 'mobile and operatorcode are required' });
    const result = await planApiService.fetchDthCustomerInfo(mobile, operatorcode);
    res.status(200).json(result);
  } catch (error) {
    console.error('[PlanAPI Proxy Error]', error.message);
    res.status(500).json({ success: false, message: 'Failed to fetch from PlanAPI' });
  }
};

// @desc    Fetch DTH Plans
// @route   GET /api/plans/dth/packs
// @access  Private
const fetchDthPlans = async (req, res, next) => {
  try {
    const { operatorcode } = req.query;
    if (!operatorcode) return res.status(400).json({ success: false, message: 'operatorcode is required' });

    let targetOp = null;
    if (mongoose.Types.ObjectId.isValid(operatorcode)) {
      targetOp = await ProviderOperator.findById(operatorcode);
    } else {
      targetOp = await ProviderOperator.findOne({
        $or: [
          { plansApiCode: String(operatorcode).trim() },
          { plansInfoCode: String(operatorcode).trim() },
          { code: String(operatorcode).trim().toUpperCase() },
          { name: new RegExp(`^${operatorcode.trim()}$`, 'i') }
        ]
      });
    }

    const plansApiOpCode = resolvePlansApiOperatorCode(targetOp || operatorcode);
    const opName = targetOp ? targetOp.name : (
      operatorcode === '24' ? 'AIRTEL DTH' :
      operatorcode === '25' ? 'DISH TV' :
      operatorcode === '26' ? 'RELIANCE BIGTV' :
      operatorcode === '27' ? 'SUN DIRECT' :
      operatorcode === '28' ? 'TATA SKY' :
      operatorcode === '29' ? 'VIDEOCON D2H' : operatorcode
    );
    const opId = targetOp ? (targetOp._id || targetOp.id).toString() : 'N/A';
    const rechargeCode = targetOp ? (targetOp.a1TopupCode || targetOp.code) : 'N/A';

    console.log('\n====================================================');
    console.log('[PLAN API OPERATOR RESOLUTION]');
    console.log(`operatorId=${opId}`);
    console.log(`operatorName=${opName}`);
    console.log(`rechargeCode=${rechargeCode}`);
    console.log(`plansApiCode=${plansApiOpCode}`);
    console.log(`serviceType=DTH`);
    console.log('====================================================\n');

    console.log('\n====================================================');
    console.log('[PLAN API REQUEST]');
    console.log(`operatorcode=${plansApiOpCode}`);
    console.log(`circle=N/A`);
    console.log('====================================================\n');

    const result = await planApiService.fetchDthPlans(plansApiOpCode);
    res.status(200).json(result);
  } catch (error) {
    console.error('[PlanAPI Proxy Error]', error.message);
    res.status(500).json({ success: false, message: 'Failed to fetch from PlanAPI' });
  }
};

// @desc    Check PlanAPI Last Recharge (Airtel & VI only)
// @route   GET /api/plans/last-recharge-check
// @access  Private
const checkLastRecharge = async (req, res) => {
  try {
    const { mobileNumber, operatorCode } = req.query;
    if (!mobileNumber || !operatorCode) {
      return res.status(400).json({ success: false, message: 'mobileNumber and operatorCode are required' });
    }

    const result = await planApiService.checkLastRecharge(mobileNumber, operatorCode);
    return res.status(200).json(result);
  } catch (error) {
    console.error('[PlanAPI Controller checkLastRecharge Error]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Check PlanAPI Recharge Expiry (Airtel & VI only)
// @route   GET /api/plans/recharge-expiry
// @access  Private
const checkRechargeExpiry = async (req, res) => {
  try {
    const { mobileNumber, operatorCode } = req.query;
    if (!mobileNumber || !operatorCode) {
      return res.status(400).json({ success: false, message: 'mobileNumber and operatorCode are required' });
    }

    const result = await planApiService.checkRechargeExpiry(mobileNumber, operatorCode);
    return res.status(200).json(result);
  } catch (error) {
    console.error('[PlanAPI Controller checkRechargeExpiry Error]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  detectMobileOperator,
  fetchMobilePlans,
  detectDthOperator,
  fetchDthCustomerInfo,
  fetchDthPlans,
  checkLastRecharge,
  checkRechargeExpiry,
};
