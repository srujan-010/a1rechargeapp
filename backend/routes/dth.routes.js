const express = require('express');
const router = express.Router();
const {
  executeDthRecharge,
  checkDthStatus,
  getDthHistory,
  getDthOperators,
  getDthPacks
} = require('../controllers/dthRecharge.controller');
const { protect } = require('../middleware/authMiddleware');

// Protect all DTH routes
router.use(protect);

router.post('/recharge', executeDthRecharge);
router.get('/status/:orderId', checkDthStatus);
router.get('/history', getDthHistory);
router.get('/operators', getDthOperators);
router.get('/packs', getDthPacks);

module.exports = router;
