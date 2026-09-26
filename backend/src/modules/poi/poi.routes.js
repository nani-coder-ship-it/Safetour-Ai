const express = require('express');
const { getNearbyPOIs, searchPlaces } = require('./poi.controller');
const { protect } = require('../../middleware/auth.middleware');

const router = express.Router();

/**
 * @route   GET /api/v1/poi/nearby
 * @desc    Get nearby POIs by type and coordinates
 * @access  Private
 */
router.get('/nearby', protect, getNearbyPOIs);

/**
 * @route   GET /api/v1/poi/search
 * @desc    Search places by text query with coordinates
 * @access  Private
 */
router.get('/search', protect, searchPlaces);

module.exports = router;
