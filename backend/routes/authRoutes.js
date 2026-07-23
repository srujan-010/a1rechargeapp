const express = require('express');
const router = express.Router();
const {
  loginUser,
  verifyOtp,
  firebaseLogin,
  registerRetailer,
  getMe,
  msg91Login,
} = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');

router.post('/send-otp', loginUser);
router.get('/send-otp', (req, res) => {
  res.status(405).json({ message: 'Use POST method' });
});
router.post('/verify-otp', verifyOtp);
router.post('/msg91-login', msg91Login);
router.post('/firebase-login', firebaseLogin);
router.post('/register', registerRetailer);
router.get('/me', protect, getMe);

module.exports = router;
