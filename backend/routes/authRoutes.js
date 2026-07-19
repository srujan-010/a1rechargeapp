const express = require('express');
const router = express.Router();
const {
  loginUser,
  verifyOtp,
  setupMpin,
  changeMpin,
  firebaseLogin,
  registerRetailer,
  getMe,
} = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');

router.post('/send-otp', loginUser);
router.get('/send-otp', (req, res) => {
  res.status(405).json({ message: 'Use POST method' });
});
router.post('/verify-otp', verifyOtp);
router.post('/firebase-login', firebaseLogin);
router.post('/register', registerRetailer);
router.post('/setup-mpin', protect, setupMpin);
router.put('/change-mpin', protect, changeMpin);
router.get('/me', protect, getMe);

module.exports = router;
