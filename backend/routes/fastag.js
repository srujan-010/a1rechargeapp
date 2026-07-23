const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { getOperators, fetchDetails, payBill, checkStatus } = require('../controllers/fastagController');

// Operator routes
router.get('/operators', getOperators);

// Fetch Details
router.post('/fetch', protect, fetchDetails);

// Pay Bill
router.post('/pay', protect, payBill);

// Check Status
router.get('/status/:orderId', protect, checkStatus);

module.exports = router;
