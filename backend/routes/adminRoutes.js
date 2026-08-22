const express = require('express');
const router = express.Router();
const {
  creditRetailerWallet,
  searchRetailers,
  getAuditLogs,
  getFundingTransactions,
} = require('../controllers/adminWalletController');
const { protect, admin } = require('../middleware/authMiddleware');

// Protect all admin routes
router.use(protect);
router.use(admin);

// Admin Wallet Management Endpoints
router.post('/wallet/credit', creditRetailerWallet);
router.get('/retailers/search', searchRetailers);
router.get('/audit-logs', getAuditLogs);
router.get('/wallet-funding-transactions', getFundingTransactions);

module.exports = router;
