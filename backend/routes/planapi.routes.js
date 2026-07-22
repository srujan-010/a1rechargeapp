const express = require('express');
const router = express.Router();
const {
  detectMobileOperator,
  fetchMobilePlans,
  detectDthOperator,
  fetchDthCustomerInfo,
  fetchDthPlans
} = require('../controllers/planapi.controller');
const { protect } = require('../middleware/authMiddleware');

// Protect all plan routes - only logged in users can fetch plans
router.use(protect);

router.get('/mobile/operator', detectMobileOperator);
router.get('/mobile/packs', fetchMobilePlans);
router.get('/dth/operator', detectDthOperator);
router.get('/dth/info', fetchDthCustomerInfo);
router.get('/dth/packs', fetchDthPlans);

module.exports = router;
