const express = require('express');
const {
  getUserAlerts,
  getUnreadCount,
  markAlertAsRead,
} = require('./alerts.controller');
const { protect } = require('../../middleware/auth.middleware');

const router = express.Router();

// All alert routes require authentication
router.use(protect);

router.get('/', getUserAlerts);
router.get('/unread-count', getUnreadCount);
router.patch('/:id/read', markAlertAsRead);

module.exports = router;
