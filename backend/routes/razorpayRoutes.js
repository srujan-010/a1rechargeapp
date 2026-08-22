const express = require('express');
const router = express.Router();
const {
  createOrder,
  verifyPayment,
  reportPaymentFailure,
} = require('../controllers/razorpayWalletController');
const { protect } = require('../middleware/authMiddleware');

router.use(protect);

router.post('/create-order', createOrder);
router.post('/verify-payment', verifyPayment);
router.post('/payment-failed', reportPaymentFailure);

module.exports = router;
