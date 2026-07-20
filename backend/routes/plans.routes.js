const express = require('express');
const router = express.Router();
const { 
  getMobilePrepaidPlans,
  getMobilePostpaidPlans,
  getDthPacks,
  getDthPackDetails,
  getDthAlacarte
} = require('../controllers/plans.controller');
const { protect } = require('../middleware/authMiddleware');

router.get('/test', (req, res) => {
  res.json({
    success: true,
    message: "Plans routes are working"
  });
});

router.get('/mobile/prepaid', protect, getMobilePrepaidPlans);
router.get('/mobile/postpaid', protect, getMobilePostpaidPlans);
router.get('/dth/packs', protect, getDthPacks);
router.get('/dth/pack', protect, getDthPackDetails);
router.get('/dth/alacarte', protect, getDthAlacarte);

module.exports = router;
