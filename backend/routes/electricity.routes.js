const express = require('express');
const router = express.Router();
const { getOperators, getOperator, getOperatorByCode, getDistrictsByOperatorCode, getStates, fetchBill } = require('../controllers/electricity.controller');

router.route('/states').get(getStates);
router.route('/operators').get(getOperators);
router.route('/operators/:operatorCode/districts').get(getDistrictsByOperatorCode);
router.route('/operators/:id').get(getOperator);
router.route('/operators/code/:operatorCode').get(getOperatorByCode);
router.route('/fetch').post(fetchBill);

module.exports = router;
