const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { getOperators, fetchBill, payBill, checkStatus } = require('../controllers/gasController');

// Operator routes
router.get('/operators', getOperators);

// Fetch Bill
router.post('/fetch', protect, fetchBill);

// Pay Bill
router.post('/pay', protect, payBill);

// Check Status
router.get('/status/:orderId', protect, checkStatus);

module.exports = router;
