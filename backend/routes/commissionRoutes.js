const express = require('express');
const router = express.Router();
const { getActiveSlabs } = require('../controllers/commissionController');

// The route is /api/commission/slabs
// No auth middleware for now to ensure it works even if token is weird
router.get('/slabs', getActiveSlabs);

module.exports = router;
