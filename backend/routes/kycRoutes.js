const express = require('express');
const router = express.Router();
const { getKycDetails, submitKycDetails, getKycStatus } = require('../controllers/kycController');
const { protect } = require('../middleware/authMiddleware');

router.get('/status', protect, getKycStatus);

router.route('/')
  .get(protect, getKycDetails)
  .post(protect, submitKycDetails)
  .put(protect, submitKycDetails);

module.exports = router;
