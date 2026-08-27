const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const {
  getSavings,
  getBenefits,
  getCurrentPlan,
  getLastRecharge,
  getPendingRecharge,
  getLastSuccessfulRecharge,
  getPersonalTransactions,
  getRecentTransactions,
  getFrequentNumbers,
} = require('../controllers/personalController');

router.use(protect);

router.get('/savings', getSavings);
router.get('/benefits', getBenefits);
router.get('/current-plan', getCurrentPlan);
router.get('/last-recharge', getLastRecharge);
router.get('/pending-recharge', getPendingRecharge);
router.get('/last-successful', getLastSuccessfulRecharge);
router.get('/transactions', getPersonalTransactions);
router.get('/history', getPersonalTransactions);
router.get('/recent-transactions', getRecentTransactions);
router.get('/frequent-numbers', getFrequentNumbers);

module.exports = router;
