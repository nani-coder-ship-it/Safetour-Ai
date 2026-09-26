const geofenceService = require('./geofence.service');

/**
 * @desc    Create a new danger zone (Admin only)
 * @route   POST /api/v1/geofence/zones
 * @access  Private/Admin
 */
const createZone = async (req, res, next) => {
  try {
    // Check if user is admin
    if (req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to perform this action',
      });
    }

    const { name, zoneType, coordinates, source } = req.body;

    if (!name || !zoneType || !coordinates) {
      return res.status(400).json({
        success: false,
        message: 'Please provide name, zoneType, and coordinates',
      });
    }

    const newZone = await geofenceService.createZone(req.body);

    res.status(201).json({
      success: true,
      data: newZone,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get all active danger zones
 * @route   GET /api/v1/geofence/zones
 * @access  Private
 */
const getActiveZones = async (req, res, next) => {
  try {
    const zones = await geofenceService.listActiveZones();
    
    res.status(200).json({
      success: true,
      count: zones.length,
      data: zones,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createZone,
  getActiveZones,
};
