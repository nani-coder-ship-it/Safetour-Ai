const SafetyService = require('./safety.service');

/**
 * @desc    Get AI GAT Service health and model status
 * @route   GET /api/v1/safety/status
 * @access  Public
 */
exports.getSafetyStatus = async (req, res, next) => {
  try {
    const health = await SafetyService.getServiceHealth();
    return res.status(200).json({
      success: true,
      data: health
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Check road safety at current GPS position
 * @route   POST /api/v1/safety/check-location
 * @access  Public / Protected
 */
exports.checkLocationSafety = async (req, res, next) => {
  try {
    const { lat, lng } = req.body;
    if (lat === undefined || lng === undefined) {
      return res.status(400).json({
        success: false,
        error: 'Please provide both lat and lng in request body.'
      });
    }

    const result = await SafetyService.checkLocationSafety(lat, lng);
    return res.status(200).json({
      success: true,
      data: result
    });
  } catch (error) {
    return res.status(502).json({
      success: false,
      error: 'Unable to reach GAT AI Service. Ensure ai-service is running on port 5001.',
      details: error.message
    });
  }
};

/**
 * @desc    Evaluate route waypoints for safety
 * @route   POST /api/v1/safety/evaluate-route
 * @access  Public / Protected
 */
exports.evaluateRoute = async (req, res, next) => {
  try {
    const { coordinates } = req.body;
    if (!coordinates || !Array.isArray(coordinates) || coordinates.length < 2) {
      return res.status(400).json({
        success: false,
        error: 'Please provide at least 2 coordinate points in array.'
      });
    }

    const result = await SafetyService.evaluateRoute(coordinates);
    return res.status(200).json({
      success: true,
      data: result
    });
  } catch (error) {
    return res.status(502).json({
      success: false,
      error: 'Unable to reach GAT AI Service. Ensure ai-service is running on port 5001.',
      details: error.message
    });
  }
};
