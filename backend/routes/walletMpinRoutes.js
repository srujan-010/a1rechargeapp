const express = require('express');
const router = express.Router();
const {
  createMpin,
  verifyMpin,
  changeMpin,
  sendForgotOtp,
  verifyForgotOtp,
  resetMpin,
  getStatus,
} = require('../controllers/walletMpinController');
const { protect } = require('../middleware/authMiddleware');

router.post('/create', protect, createMpin);
router.post('/verify', protect, verifyMpin);
router.post('/change', protect, changeMpin);
router.post('/forgot/send-otp', protect, sendForgotOtp);
router.post('/forgot/verify-otp', protect, verifyForgotOtp);
router.post('/reset', protect, resetMpin);
router.get('/status', protect, getStatus);

module.exports = router;
