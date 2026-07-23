const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { getOperators, getOperator, getOperatorByCode, getDistrictsByOperatorCode, getStates, fetchBill, payBill, checkStatus } = require('../controllers/electricity.controller');

router.route('/states').get(getStates);
router.route('/operators').get(getOperators);
router.route('/operators/:operatorCode/districts').get(getDistrictsByOperatorCode);
router.route('/operators/:id').get(getOperator);
router.route('/operators/code/:operatorCode').get(getOperatorByCode);
router.route('/fetch').post(protect, fetchBill);
router.route('/pay').post(protect, payBill);
router.route('/status/:orderId').get(protect, checkStatus);

module.exports = router;
