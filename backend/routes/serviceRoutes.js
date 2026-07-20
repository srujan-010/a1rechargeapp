const express = require('express');
const router = express.Router();
const { processDmtTransfer } = require('../controllers/serviceController');
const { executeRecharge } = require('../controllers/recharge.controller');
const { protect } = require('../middleware/authMiddleware');

router.use(protect);

router.post('/recharge/initiate', executeRecharge);
router.post('/dmt/transfer', processDmtTransfer);

module.exports = router;
