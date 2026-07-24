const express = require('express');
const router = express.Router();
const {
  getNotifications,
  markAsRead,
  markAllAsRead,
  deleteNotification,
  createAdminBroadcast,
  registerDevice,
  testPushNotification
} = require('../controllers/notificationController');

const { protect } = require('../middleware/authMiddleware');

router.use(protect);

router.get('/', getNotifications);
router.post('/register-device', registerDevice);
router.post('/test', testPushNotification);
router.patch('/read-all', markAllAsRead);
router.patch('/:id/read', markAsRead);
router.delete('/:id', deleteNotification);

// Admin route (in production, add admin middleware)
router.post('/admin', createAdminBroadcast);

module.exports = router;
