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

const { resolvePlansApiOperatorCode } = require('../utils/operatorMapper');

// @desc    Fetch Mobile Plans
// @route   GET /api/plans/mobile/packs
// @access  Private
const fetchMobilePlans = async (req, res, next) => {
  try {
    const { operatorcode, circle, mobile } = req.query;
    if (!operatorcode || !circle) return res.status(400).json({ success: false, message: 'operatorcode and circle are required' });

    const plansApiOpCode = resolvePlansApiOperatorCode(operatorcode);

    console.log('\n[PLAN API]');
    console.log(`Mobile: ${mobile || 'N/A'}`);
    console.log(`Input Operator: ${operatorcode}`);
    console.log(`PlanAPI Operator Code: ${plansApiOpCode}`);
    console.log(`Circle Code: ${circle}`);

    console.log('\n[PLAN API OUTBOUND]');
    console.log(`operatorcode: ${plansApiOpCode}`);
    console.log(`cricle: ${circle}`);

    const result = await planApiService.fetchMobilePlans(plansApiOpCode, circle);

    console.log('\n[PLAN API RESPONSE]');
    if (result && result.data) {
      console.log(`ERROR: ${result.data.ERROR}`);
      console.log(`STATUS: ${result.data.STATUS}`);
      console.log(`MESSAGE: ${result.data.Message || result.data.MESSAGE || 'N/A'}`);
      console.log(`RDATA: ${result.data.RDATA ? (Array.isArray(result.data.RDATA) ? `${result.data.RDATA.length} plans` : 'populated') : 'null'}`);
    }

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
    const result = await planApiService.fetchDthPlans(operatorcode);
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
