const express = require('express');
const router = express.Router();
const { 
  checkProviderHealth, 
  checkProviderBalance,
  getOperators,
  getPlans,
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
router.post('/mobile', protect, executeRecharge);
router.get('/status/:orderId', protect, checkStatus);

// Provider Webhook - Public
router.post('/callback', providerCallback);
router.get('/callback', providerCallback);

module.exports = router;
