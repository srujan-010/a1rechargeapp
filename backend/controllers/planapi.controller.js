const planApiService = require('../services/planapi.service');

// @desc    Detect Mobile Operator
// @route   GET /api/plans/mobile/operator
// @access  Private
const detectMobileOperator = async (req, res, next) => {
  try {
    const { mobile } = req.query;
    if (!mobile) return res.status(400).json({ success: false, message: 'mobile is required' });
    const result = await planApiService.detectMobileOperator(mobile);
    res.status(200).json(result);
  } catch (error) {
    console.error('[PlanAPI Proxy Error]', error.message);
    res.status(500).json({ success: false, message: 'Failed to fetch from PlanAPI' });
  }
};

// @desc    Fetch Mobile Plans
// @route   GET /api/plans/mobile/packs
// @access  Private
const fetchMobilePlans = async (req, res, next) => {
  try {
    const { operatorcode, circle } = req.query;
    if (!operatorcode || !circle) return res.status(400).json({ success: false, message: 'operatorcode and circle are required' });
    const result = await planApiService.fetchMobilePlans(operatorcode, circle);
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

module.exports = {
  detectMobileOperator,
  fetchMobilePlans,
  detectDthOperator,
  fetchDthCustomerInfo,
  fetchDthPlans
};
