const express = require('express');
const router = express.Router();
const {
  sendOtp,
  verifyOtp,
  resendOtp,
  registerRetailer,
  getMe,
  firebaseLogin,
} = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');

// Fast2SMS WhatsApp Authentication Endpoints
router.post('/send-otp', sendOtp);
router.get('/send-otp', (req, res) => {
  res.status(405).json({ success: false, message: 'Use POST method' });
});

router.post('/verify-otp', verifyOtp);
router.post('/resend-otp', resendOtp);

// Onboarding & Profile
router.post('/register', registerRetailer);
router.get('/me', protect, getMe);
router.post('/firebase-login', firebaseLogin);

module.exports = router;
