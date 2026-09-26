const DangerZone = require('./geofence.model');

/**
 * Creates a new danger zone
 * @param {Object} data - The zone data including name, zoneType, and coordinates
 */
const createZone = async (data) => {
  const { name, zoneType, coordinates, source } = data;
  
  const newZone = await DangerZone.create({
    name,
    zoneType,
    polygon: {
      type: 'Polygon',
      coordinates: coordinates, // Expecting [[[lng, lat], ...]]
    },
    source: source || 'manual',
  });
  
  return newZone;
};

/**
 * Retrieves all active danger zones
 */
const listActiveZones = async () => {
  return await DangerZone.find({ active: true }).sort({ createdAt: -1 });
};

/**
 * Checks if a given GPS point falls inside any active danger zone.
 * Uses MongoDB $geoIntersects with a GeoJSON Point.
 * 
 * @param {Number} lat - Latitude
 * @param {Number} lng - Longitude
 * @returns {Array} Array of zones the point is currently inside
 */
const checkPointInZones = async (lat, lng) => {
  const point = {
    type: 'Point',
    coordinates: [lng, lat], // GeoJSON order is Longitude, Latitude
  };

  const zones = await DangerZone.find({
    active: true,
    polygon: {
      $geoIntersects: {
        $geometry: point,
      },
    },
  });

  return zones;
};

module.exports = {
  createZone,
  listActiveZones,
  checkPointInZones,
};
