const express = require('express');
const { saveLocation, getLatestLocation, getLocationHistory } = require('./location.controller');
const { protect } = require('../../middleware/auth.middleware');

const router = express.Router();

router.post('/', protect, saveLocation);
router.get('/:userId/latest', protect, getLatestLocation);
router.get('/:userId/history', protect, getLocationHistory);

module.exports = router;
