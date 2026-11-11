const locationService = require('./location.service');
const authService = require('../auth/auth.service'); 

const saveLocation = async (req, res, next) => {
  try {
    let { lat, lng, speed, battery, network } = req.body;

    if (lat === undefined || lng === undefined) {
      res.status(400);
      throw new Error('Please provide lat and lng');
    }

    // Auto-normalize swapped latitude and longitude (e.g. tester swapped lat ~77° and lng ~9° in Fake GPS for India/Tamil Nadu)
    if (lat > 60 && lng < 40 && lat <= 90) {
      console.log(`[COORDINATES NORMALIZED] Auto-swapped Lat (${lat}) and Lng (${lng}) -> normalized to Lat: ${lng}, Lng: ${lat}`);
      const temp = lat;
      lat = lng;
      lng = temp;
    }

    // Resolve the MongoDB User from the Firebase token UID
    const user = await authService.getUserByFirebaseUid(req.user.uid);

    const { location, triggeredAlerts } = await locationService.saveLocation(
      user._id, 
      lat, 
      lng, 
      { speed, battery, network }
    );

    console.log(`[LOCATION RECEIVED] User ${user.email} -> Lat: ${lat}, Lng: ${lng}`);
    if (triggeredAlerts.length > 0) {
      console.log(`[GEOFENCE ALERT] Triggered ${triggeredAlerts.length} alerts for ${user.email}`);
    }

    res.status(201).json({
      success: true,
      data: {
        location,
        triggeredAlerts,
      },
      message: 'Location saved successfully',
    });
  } catch (error) {
    next(error);
  }
};

const getLatestLocation = async (req, res, next) => {
  try {
    const targetUserId = req.params.userId;
    
    // Resolve requester to check role and ID
    const requester = await authService.getUserByFirebaseUid(req.user.uid);

    // Authorization: only the user themselves or an admin can access
    if (requester._id.toString() !== targetUserId && requester.role !== 'admin') {
      res.status(403);
      throw new Error('Not authorized to access this location data');
    }

    const location = await locationService.getLatestLocation(targetUserId);

    res.status(200).json({
      success: true,
      data: location,
      message: 'Latest location retrieved successfully',
    });
  } catch (error) {
    next(error);
  }
};

const getLocationHistory = async (req, res, next) => {
  try {
    const targetUserId = req.params.userId;
    
    // Resolve requester to check role
    const requester = await authService.getUserByFirebaseUid(req.user.uid);

    // Admin-only route
    if (requester.role !== 'admin') {
      res.status(403);
      throw new Error('Not authorized, admin access required');
    }

    const history = await locationService.getLocationHistory(targetUserId, 50);

    res.status(200).json({
      success: true,
      data: history,
      message: 'Location history retrieved successfully',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  saveLocation,
  getLatestLocation,
  getLocationHistory,
};
