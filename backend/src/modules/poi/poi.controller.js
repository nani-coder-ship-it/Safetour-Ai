const poiService = require('./poi.service');

const VALID_POI_TYPES = [
  'hotel',
  'hospital',
  'pharmacy',
  'police',
  'restaurant',
  'atm',
  'bank',
  'petrol_pump',
  'toilet',
  'bus_stop',
  'railway_station',
  'shopping',
  'supermarket',
  'college',
  'university',
  'tourist_spot',
  'place',
];

/**
 * @desc    Get nearby POIs by type, coordinates, and radius
 * @route   GET /api/v1/poi/nearby?type=&lat=&lng=&radius=
 * @access  Private (Protected via Firebase Auth)
 */
const getNearbyPOIs = async (req, res, next) => {
  try {
    const { type, lat, lng, radius, subType, search } = req.query;

    // Validate required fields
    if (!type || lat === undefined || lng === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Please provide type, lat, and lng query parameters',
      });
    }

    // Validate POI type
    const normalizedType = type.toLowerCase().trim();
    if (!VALID_POI_TYPES.includes(normalizedType)) {
      return res.status(400).json({
        success: false,
        message: `Invalid POI type: "${type}". Allowed types: ${VALID_POI_TYPES.join(', ')}`,
      });
    }

    // Validate coordinates
    const parsedLat = parseFloat(lat);
    const parsedLng = parseFloat(lng);
    if (isNaN(parsedLat) || isNaN(parsedLng) || parsedLat < -90 || parsedLat > 90 || parsedLng < -180 || parsedLng > 180) {
      return res.status(400).json({
        success: false,
        message: 'Please provide valid numerical coordinates for lat (-90 to 90) and lng (-180 to 180)',
      });
    }

    // Call POI service (with 7-day caching and Overpass integration)
    try {
      const pois = await poiService.getNearby(parsedLat, parsedLng, radius, normalizedType, {
        subType: subType ? subType.trim() : undefined,
        search: search ? search.trim() : undefined,
      });

      res.status(200).json({
        success: true,
        count: pois.length,
        data: pois,
        message: pois.length === 0 ? 'No nearby places found for this search area' : 'Nearby places retrieved successfully',
      });
    } catch (err) {
      if (err.name === 'OverpassTimeoutError' || err.isTimeout) {
        console.warn(`[POI Controller] ⏱️ Overpass timeout caught: ${err.message}`);
        return res.status(200).json({
          success: false,
          data: [],
          message: 'Nearby search is taking too long — try again',
        });
      }
      if (err.name === 'OverpassQueryError') {
        console.warn(`[POI Controller] ⚠️ Overpass error caught: ${err.message}`);
        return res.status(200).json({
          success: false,
          data: [],
          message: 'Nearby search is taking too long — try again',
        });
      }
      throw err;
    }
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Search places by free-form query (OpenStreetMap Nominatim + local cache)
 * @route   GET /api/v1/poi/search?q=&lat=&lng=
 * @access  Private
 */
const searchPlaces = async (req, res, next) => {
  try {
    const { q, lat, lng } = req.query;
    if (!q || q.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Query parameter "q" is required',
      });
    }

    const parsedLat = lat ? parseFloat(lat) : undefined;
    const parsedLng = lng ? parseFloat(lng) : undefined;

    const places = await poiService.searchPlaces(q, parsedLat, parsedLng);
    res.status(200).json({
      success: true,
      count: places.length,
      data: places,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getNearbyPOIs,
  searchPlaces,
  VALID_POI_TYPES,
};
