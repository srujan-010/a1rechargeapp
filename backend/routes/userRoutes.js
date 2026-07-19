const express = require('express');
const router = express.Router();
const {
  getProfile,
  updateProfile,
  getBank,
  updateBank,
  getKyc,
  uploadKyc,
  uploadAvatar,
  getRecentContacts,
  syncRecentContacts,
} = require('../controllers/userController');
const { protect } = require('../middleware/authMiddleware');
const { uploadKyc: upload } = require('../middleware/upload');

router.get('/profile', protect, getProfile);
router.put('/profile', protect, updateProfile);
router.get('/bank', protect, getBank);
router.put('/bank', protect, updateBank);
router.get('/kyc', protect, getKyc);
router.post('/kyc/upload', protect, upload.single('document'), uploadKyc);
router.post('/profile/avatar', protect, upload.single('avatar'), uploadAvatar);

router.get('/recent-contacts', protect, getRecentContacts);
router.put('/recent-contacts', protect, syncRecentContacts);

module.exports = router;
