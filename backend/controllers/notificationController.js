const Notification = require('../models/Notification');
const mongoose = require('mongoose');

// @desc    Get all notifications for logged in user (with pagination)
// @route   GET /api/notifications
// @access  Private
exports.getNotifications = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    // Fetch user specific and system broadcast notifications
    const query = {
      $or: [
        { userId: req.user._id },
        { userId: null } // System broadcasts
      ]
    };

    const notifications = await Notification.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await Notification.countDocuments(query);
    const unreadCount = await Notification.countDocuments({ ...query, isRead: false });

    res.status(200).json({
      success: true,
      count: notifications.length,
      total,
      unreadCount,
      page,
      pages: Math.ceil(total / limit),
      data: notifications
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Mark a notification as read
// @route   PATCH /api/notifications/:id/read
// @access  Private
exports.markAsRead = async (req, res, next) => {
  try {
    const notification = await Notification.findById(req.params.id);

    if (!notification) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }

    // Check if notification belongs to user or is system
    if (notification.userId && notification.userId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Not authorized to update this notification' });
    }

    notification.isRead = true;
    await notification.save();

    res.status(200).json({ success: true, data: notification });
  } catch (error) {
    next(error);
  }
};

// @desc    Mark all user notifications as read
// @route   PATCH /api/notifications/read-all
// @access  Private
exports.markAllAsRead = async (req, res, next) => {
  try {
    const query = {
      $or: [
        { userId: req.user._id },
        { userId: null }
      ],
      isRead: false
    };

    await Notification.updateMany(query, { $set: { isRead: true } });

    res.status(200).json({ success: true, message: 'All notifications marked as read' });
  } catch (error) {
    next(error);
  }
};

// @desc    Delete a notification
// @route   DELETE /api/notifications/:id
// @access  Private
exports.deleteNotification = async (req, res, next) => {
  try {
    const notification = await Notification.findById(req.params.id);

    if (!notification) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }

    if (notification.userId && notification.userId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Not authorized to delete this notification' });
    }

    await notification.deleteOne();

    res.status(200).json({ success: true, data: {} });
  } catch (error) {
    next(error);
  }
};

// @desc    Create a notification (Admin / System Internal)
// @route   POST /api/notifications/admin
// @access  Private/Admin
exports.createAdminBroadcast = async (req, res, next) => {
  try {
    // In a real app, verify req.user.role === 'admin'
    
    const { targetUserId, title, message, category, priority, action, actionData } = req.body;

    const notification = await Notification.create({
      userId: targetUserId || null, // null means all users
      title,
      message,
      category,
      priority,
      action,
      actionData
    });

    res.status(201).json({ success: true, data: notification });
  } catch (error) {
    next(error);
  }
};
