const express = require('express');
const router = express.Router();
const { 
  checkProviderHealth, 
  checkProviderBalance,
  getOperators,
  getPlans,
  calculateRechargePayable,
  createRazorpayRechargeOrder,
  verifyRazorpayRechargePayment,
  executeRecharge,
  checkStatus,
  providerCallback
} = require('../controllers/recharge.controller');
const { protect, admin } = require('../middleware/authMiddleware');

// Health Check API - Admin only
router.get('/health', protect, admin, checkProviderHealth);

// Balance Check API - Admin only
router.get('/balance', protect, admin, checkProviderBalance);

// Operators and Plans API - Admin only
router.get('/operators', protect, admin, getOperators);
router.get('/plans', protect, admin, getPlans);

// Recharge API - Retailer
router.post('/calculate-payable', protect, calculateRechargePayable);
router.post('/create-razorpay-order', protect, createRazorpayRechargeOrder);
router.post('/verify-razorpay-payment', protect, verifyRazorpayRechargePayment);
router.post('/mobile', protect, (req, res, next) => {
  console.log(`[${new Date().toISOString()}] [1] ROUTE ENTERED: ${req.method} ${req.originalUrl}`);
  next();
}, executeRecharge);
router.get('/status/:orderId', protect, checkStatus);

// Provider Webhook - Public
router.post('/callback', providerCallback);
router.get('/callback', providerCallback);

module.exports = router;
