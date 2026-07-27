const express = require('express');
const router = express.Router();
const { getActiveSlabs, updateCommission } = require('../controllers/commissionController');

// GET active commission slabs (supports /api/commission and /api/commission/slabs)
router.get('/slabs', getActiveSlabs);
router.get('/', getActiveSlabs);

// PUT update commission rate (Admin Dashboard endpoint)
router.put('/update', updateCommission);
router.post('/update', updateCommission);

module.exports = router;
