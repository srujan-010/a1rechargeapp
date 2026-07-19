const express = require('express');
const router = express.Router();
const { processRecharge, processDmtTransfer } = require('../controllers/serviceController');
const { protect } = require('../middleware/authMiddleware');

router.use(protect);

router.post('/recharge/initiate', processRecharge);
router.post('/dmt/transfer', processDmtTransfer);

module.exports = router;
