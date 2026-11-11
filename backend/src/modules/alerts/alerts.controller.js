const mongoose = require('mongoose');
const alertsService = require('./alerts.service');
const User = require('../auth/auth.model');

/**
 * Helper to ensure we have the MongoDB ObjectId for the authenticated user
 */
const resolveUserId = async (user) => {
  if (user && user._id) return user._id;
  if (user && user.uid) {
    const dbUser = await User.findOne({ firebaseUid: user.uid });
    if (dbUser) return dbUser._id;
  }
  return null;
};

/**
 * @desc    Get authenticated user's alerts (paginated, newest first)
 * @route   GET /api/v1/alerts
 * @access  Private
 */
const getUserAlerts = async (req, res, next) => {
  try {
    const userId = await resolveUserId(req.user);
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User profile not found',
      });
    }

    const { limit, skip, page, lat, lng, radius } = req.query;
    const alerts = await alertsService.getUserAlerts(userId, {
      limit,
      skip,
      page,
      lat: lat !== undefined ? parseFloat(lat) : undefined,
      lng: lng !== undefined ? parseFloat(lng) : undefined,
      radiusKm: radius !== undefined ? parseFloat(radius) : 25,
    });

    res.status(200).json({
      success: true,
      count: alerts.length,
      data: alerts,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get count of unread/active alerts for badge display
 * @route   GET /api/v1/alerts/unread-count?lat=&lng=&radius=
 * @access  Private
 */
const getUnreadCount = async (req, res, next) => {
  try {
    const userId = await resolveUserId(req.user);
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User profile not found',
      });
    }

    const { lat, lng, radius } = req.query;
    const count = await alertsService.getUnreadCount(userId, {
      lat: lat !== undefined ? parseFloat(lat) : undefined,
      lng: lng !== undefined ? parseFloat(lng) : undefined,
      radiusKm: radius !== undefined ? parseFloat(radius) : 25,
    });

    res.status(200).json({
      success: true,
      data: {
        unreadCount: count,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Mark a specific alert as acknowledged/read (Ownership verified)
 * @route   PATCH /api/v1/alerts/:id/read
 * @access  Private
 */
const markAlertAsRead = async (req, res, next) => {
  try {
    const userId = await resolveUserId(req.user);
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User profile not found',
      });
    }

    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(404).json({
        success: false,
        message: 'Alert not found',
      });
    }

    const updatedAlert = await alertsService.markAsRead(id, userId);

    if (!updatedAlert) {
      // Reject with 404, not 403, if alert does not exist or belongs to someone else
      return res.status(404).json({
        success: false,
        message: 'Alert not found',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Alert marked as acknowledged',
      data: updatedAlert,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getUserAlerts,
  getUnreadCount,
  markAlertAsRead,
};
