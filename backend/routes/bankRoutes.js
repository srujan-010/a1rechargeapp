const express = require('express');
const router = express.Router();
const { getBankDetails, addBankDetails, deleteBankDetails } = require('../controllers/bankController');
const { protect } = require('../middleware/authMiddleware');

router.route('/')
  .get(protect, getBankDetails)
  .post(protect, addBankDetails)
  .put(protect, addBankDetails) // We use the same method for add/update
  .delete(protect, deleteBankDetails);

module.exports = router;
