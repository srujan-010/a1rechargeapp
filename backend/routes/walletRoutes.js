const express = require('express');
const router = express.Router();
const { getBalance, getStatement, topupWallet, getDashboardSummary, getDashboardAnalytics } = require('../controllers/walletController');
const { protect } = require('../middleware/authMiddleware');

router.use(protect);

router.get('/balance', getBalance);
router.get('/statement', getStatement);
router.post('/topup', topupWallet);
router.get('/summary', getDashboardSummary);
router.get('/analytics', getDashboardAnalytics);

module.exports = router;
