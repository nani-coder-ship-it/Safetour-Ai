const express = require('express');
const {
  getSafetyStatus,
  checkLocationSafety,
  evaluateRoute
} = require('./safety.controller');

const router = express.Router();

router.get('/status', getSafetyStatus);
router.post('/check-location', checkLocationSafety);
router.post('/evaluate-route', evaluateRoute);

module.exports = router;
