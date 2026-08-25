const express = require('express');
const router = express.Router();
const { processDmtTransfer } = require('../controllers/serviceController');
const { 
  executeRecharge, 
  calculateRechargePayable, 
  createRazorpayRechargeOrder, 
  verifyRazorpayRechargePayment 
} = require('../controllers/recharge.controller');
const { protect } = require('../middleware/authMiddleware');

router.use(protect);

router.post('/recharge/calculate-payable', calculateRechargePayable);
router.post('/recharge/create-razorpay-order', createRazorpayRechargeOrder);
router.post('/recharge/verify-razorpay-payment', verifyRazorpayRechargePayment);
router.post('/recharge/initiate', (req, res, next) => {
  console.log(`[${new Date().toISOString()}] [1] ROUTE ENTERED: ${req.method} ${req.originalUrl}`);
  next();
}, executeRecharge);
router.post('/dmt/transfer', processDmtTransfer);

module.exports = router;
