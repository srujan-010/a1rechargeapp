const express = require('express');
const router = express.Router();
const {
  createSecurityPin,
  verifySecurityPin,
  changeSecurityPin,
  sendForgotOtp,
  verifyForgotOtp,
  resetSecurityPin,
  getStatus,
} = require('../controllers/securityPinController');
const { protect } = require('../middleware/authMiddleware');

router.post('/create', protect, createSecurityPin);
router.post('/setup', protect, createSecurityPin);
router.post('/verify', protect, verifySecurityPin);
router.post('/change', protect, changeSecurityPin);
router.post('/forgot/send-otp', protect, sendForgotOtp);
router.post('/forgot/verify-otp', protect, verifyForgotOtp);
router.post('/reset', protect, resetSecurityPin);
router.get('/status', protect, getStatus);

module.exports = router;
