const Location = require('./location.model');
const geofenceService = require('../geofence/geofence.service');
const Alert = require('../alerts/alert.model');

/**
 * Saves a new location ping for a user.
 * We insert a new document each time to maintain a history of their route.
 */
const saveLocation = async (userId, lat, lng, extras = {}) => {
  const { speed, battery, network } = extras;

  const locationData = {
    userId,
    lat,
    lng,
    location: {
      type: 'Point',
      // GeoJSON requires [longitude, latitude]
      coordinates: [lng, lat],
    },
    speed,
    battery,
    network,
  };

  const newLocation = await Location.create(locationData);

  // GEOFENCE INTEGRATION
  // Check if this new ping falls into any active danger zones
  const activeZones = await geofenceService.checkPointInZones(lat, lng);
  const triggeredAlerts = [];

  if (activeZones && activeZones.length > 0) {
    for (const zone of activeZones) {
      // Prevent spam: Check if an active alert for this zone already exists within last 6 hours
      const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);
      const existingAlert = await Alert.findOne({
        userId,
        zoneId: zone._id,
        status: 'active',
        createdAt: { $gte: sixHoursAgo },
      });

      if (!existingAlert) {
        const alertMsg = zone.description
          ? `⚠️ ${zone.name} - ${zone.description}`
          : `⚠️ Danger Zone Alert: Entered ${zone.name}`;

        const alert = await Alert.create({
          userId,
          title: `⚡ Danger Zone Breach: Inside ${zone.name}`,
          type: 'geofence',
          severity: zone.zoneType === 'red' ? 'critical' : 'warning',
          locationName: zone.name,
          message: alertMsg,
          safetyTip: zone.description || 'Follow local safety guidelines and proceed with caution.',
          zoneId: zone._id,
          distanceKm: 0.0,
          coordinates: [lng, lat],
        });
        triggeredAlerts.push(alert);
      } else {
        triggeredAlerts.push(existingAlert);
      }
    }
  }

  return { location: newLocation, triggeredAlerts };
};

/**
 * Retrieves the most recent location ping for a user.
 */
const getLatestLocation = async (userId) => {
  // Sort by timestamp descending and get the first one
  const location = await Location.findOne({ userId }).sort({ timestamp: -1 });
  return location;
};

/**
 * Retrieves the location history for a user up to a specified limit.
 */
const getLocationHistory = async (userId, limit = 50) => {
  const history = await Location.find({ userId })
    .sort({ timestamp: -1 })
    .limit(limit);
  return history;
};

module.exports = {
  saveLocation,
  getLatestLocation,
  getLocationHistory,
};
