const express = require('express');
const { createZone, getActiveZones } = require('./geofence.controller');
const { protect } = require('../../middleware/auth.middleware');

const router = express.Router();

// All routes require authentication
router.use(protect);

router.route('/zones')
  .post(createZone)
  .get(getActiveZones);

module.exports = router;
