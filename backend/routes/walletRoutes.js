const express = require('express');
const router = express.Router();
const { getBalance, getStatement, topupWallet, getDashboardSummary, getDashboardAnalytics } = require('../controllers/walletController');
const { protect, requireRetailer } = require('../middleware/authMiddleware');

router.use(protect);

// Statement is the universal transaction history endpoint for ALL accounts (Personal and Retailer)
router.get('/statement', getStatement);

// Retailer-only wallet operations
router.get('/balance', requireRetailer, getBalance);
router.post('/topup', requireRetailer, topupWallet);
router.get('/summary', requireRetailer, getDashboardSummary);
router.get('/analytics', requireRetailer, getDashboardAnalytics);

module.exports = router;
