const express = require('express');
const router = express.Router();
const { getActiveSlabs, updateCommission } = require('../controllers/commissionController');

const { protect, requireRetailer, admin } = require('../middleware/authMiddleware');

// GET active commission slabs (supports /api/commission and /api/commission/slabs) - Retailers only
router.get('/slabs', protect, requireRetailer, getActiveSlabs);
router.get('/', protect, requireRetailer, getActiveSlabs);

// PUT update commission rate (Admin Dashboard endpoint)
router.put('/update', protect, admin, updateCommission);
router.post('/update', protect, admin, updateCommission);

module.exports = router;
