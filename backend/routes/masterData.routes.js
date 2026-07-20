const express = require('express');
const router = express.Router();
const {
  getOperators,
  getCircles,
  adminGetOperators,
  adminCreateOperator,
  adminUpdateOperator,
  adminDeleteOperator,
  adminGetCircles,
  adminCreateCircle,
  adminUpdateCircle,
  adminDeleteCircle
} = require('../controllers/masterData.controller');

const { protect, admin } = require('../middleware/authMiddleware');

// ==========================
// PUBLIC APIs
// ==========================
router.get('/operators', getOperators);
router.get('/circles', getCircles);
router.get('/resolve', require('../controllers/masterData.controller').resolveOperatorAndCircle);

// ==========================
// ADMIN APIs (Operators)
// ==========================
router.get('/admin/operators', protect, admin, adminGetOperators);
router.post('/admin/operators', protect, admin, adminCreateOperator);
router.put('/admin/operators/:id', protect, admin, adminUpdateOperator);
router.delete('/admin/operators/:id', protect, admin, adminDeleteOperator);

// ==========================
// ADMIN APIs (Circles)
// ==========================
router.get('/admin/circles', protect, admin, adminGetCircles);
router.post('/admin/circles', protect, admin, adminCreateCircle);
router.put('/admin/circles/:id', protect, admin, adminUpdateCircle);
router.delete('/admin/circles/:id', protect, admin, adminDeleteCircle);

module.exports = router;
