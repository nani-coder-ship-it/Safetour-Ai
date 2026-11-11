/**
 * Enhanced Nominatim POI Fallback Client
 * Official OpenStreetMap Foundation CDN-backed geocoding/POI service.
 * High-speed (<400ms), multi-query category support with student hostel filtering.
 */

const { isStudentAccommodation } = require('./overpass.client');

const NOMINATIM_BASE_URL = 'https://nominatim.openstreetmap.org/search';

/**
 * Multi-query specifications for each category to ensure dense, comprehensive results.
 */
const CATEGORY_SEARCH_PARAMS = {
  hotel: [
    'q=[tourism=hotel]',
    'q=[tourism=guest_house]',
    'q=[tourism=motel]',
    'q=[tourism=hostel]',
    'q=hotel',
    'q=lodge',
    'q=guest house',
    'q=resort',
    'q=motel',
  ],
  restaurant: [
    'q=restaurant',
    'q=canteen',
    'q=hotel',
    'q=mess',
    'q=bakery',
    'q=cafe',
    'q=biryani',
    'q=fast food',
  ],
  tourist_spot: [
    'q=temple',
    'q=kovil',
    'q=tourist attraction',
    'q=monument',
    'q=falls',
    'q=viewpoint',
    'q=church',
    'q=mosque',
    'q=park',
  ],
  hospital: [
    'q=hospital',
    'q=clinic',
    'q=health centre',
    'q=medical',
  ],
  pharmacy: [
    'q=pharmacy',
    'q=medical store',
    'q=chemist',
  ],
  police: [
    'q=police station',
    'q=police',
  ],
  atm: [
    'q=atm',
    'q=bank atm',
  ],
  bank: [
    'q=bank',
  ],
  petrol_pump: [
    'q=petrol pump',
    'q=fuel station',
  ],
  bus_stop: [
    'q=bus stand',
    'q=bus stop',
  ],
  railway_station: [
    'q=railway station',
  ],
  shopping: [
    'q=supermarket',
    'q=textiles',
    'q=shopping mall',
  ],
  supermarket: [
    'q=supermarket',
    'q=grocery',
  ],
  college: [
    'q=college',
    'q=university',
  ],
  university: [
    'q=university',
    'q=college',
  ],
  toilet: [
    'q=public toilet',
    'q=restroom',
  ],
};

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Query Nominatim for POIs around a given coordinate and radius across multiple structured category queries.
 *
 * @param {number} lat - Latitude
 * @param {number} lng - Longitude
 * @param {number} radiusMeters - Radius in meters
 * @param {string} type - POI category type
 * @returns {Promise<Array>} List of validated POI objects
 */
const queryNominatim = async (lat, lng, radiusMeters = 3000, type) => {
  const queryList = CATEGORY_SEARCH_PARAMS[type] || [`q=${type}`];
  
  // Expanded regional search radius (up to 12km) to capture regional towns (e.g. Srivilliputhur / Watrap)
  // for both strict within-radius matches and Requirement 11 nearest-fallback matches.
  const searchDistMeters = Math.max(radiusMeters * 1.8, 12000);
  const delta = (searchDistMeters / 111000);
  const viewbox = `${lng - delta},${lat + delta},${lng + delta},${lat - delta}`;

  console.log(`[Nominatim POI] Querying multi-tag OSM search for "${type}" around (${lat}, ${lng}) [radius: ${radiusMeters}m]...`);
  const startTime = Date.now();

  const collectedPois = [];
  const seenOsmIds = new Set();
  const excludedCount = [];

  // Query top 6 most relevant terms in parallel with a 4s timeout for dense, fast responsiveness
  const targetQueries = queryList.slice(0, 6);
  console.log(`\n=================== [NOMINATIM QUERY DETAILS] ===================`);
  console.log(`POI Type: "${type}" | Viewbox: [${viewbox}] | Search Radius: ${searchDistMeters}m`);
  console.log(`Target Search Queries: ${JSON.stringify(targetQueries)}`);
  targetQueries.forEach((q, idx) => console.log(`   Query #${idx + 1}: ${NOMINATIM_BASE_URL}?format=json&${q}&viewbox=${viewbox}&bounded=1&limit=20`));
  console.log(`=================================================================\n`);
  const queryPromises = targetQueries.map(async (param) => {
    const url = `${NOMINATIM_BASE_URL}?format=json&${param}&viewbox=${viewbox}&bounded=1&limit=20&addressdetails=1`;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 4000);

    try {
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'SafeTourAI-Backend/1.2 (https://safetour.ai; contact@safetour.ai)',
          'Accept-Language': 'en',
        },
        signal: controller.signal,
      });
      clearTimeout(timeoutId);

      if (response.ok) {
        const data = await response.json();
        if (Array.isArray(data)) {
          for (const item of data) {
            const itemLat = parseFloat(item.lat);
            const itemLng = parseFloat(item.lon);
            if (isNaN(itemLat) || isNaN(itemLng)) continue;

            // Filter out roads, highways, and administrative boundaries
            if (item.class === 'highway' || item.class === 'boundary' || item.type === 'administrative') {
              continue;
            }

            const osmId = `${item.osm_type || 'node'}/${item.osm_id || Math.floor(Math.random() * 10000000)}`;
            if (seenOsmIds.has(osmId)) continue;

            // Extract real name, requirement 12: do not create fake placeholder names
            const rawName = item.name || (item.display_name ? item.display_name.split(',')[0].trim() : null);
            if (!rawName || rawName.trim().length === 0) {
              continue;
            }
            const cleanName = rawName.trim();

            // CRITICAL: Filter student / collegiate hostels from ALL categories
            if (isStudentAccommodation(cleanName, item)) {
              excludedCount.push(cleanName);
              continue;
            }
            // Strict category check for hotel: MUST be tourism accommodation or building=hotel
            if (type === 'hotel') {
              const isTourism = item.class === 'tourism' &&
                ['hotel', 'guest_house', 'motel', 'hostel', 'resort', 'lodge', 'chalet', 'apartment'].includes(item.type);
              const isHotelBuilding = item.class === 'building' && item.type === 'hotel';
              
              // Non-hotel buildings (like canteen) or amenity (like restaurant) NEVER qualify under hotel
              if (!isTourism && !isHotelBuilding) {
                continue;
              }
            }

            // Resolve meaningful subType rather than raw OSM classes like 'building' or 'amenity'
            let resolvedSubType = type;
            if (type === 'hotel') {
              if (['guest_house', 'motel', 'hostel', 'resort', 'lodge'].includes(item.type)) {
                resolvedSubType = item.type;
              } else {
                resolvedSubType = 'hotel';
              }
            } else if (item.type && item.type !== 'yes' && item.type !== 'building') {
              resolvedSubType = item.type;
            }

            seenOsmIds.add(osmId);

            collectedPois.push({
              osmId,
              name: cleanName,
              type,
              subType: resolvedSubType,
              address: item.display_name || 'Address unavailable',
              phone: null,
              website: null,
              lat: itemLat,
              lng: itemLng,
              location: {
                type: 'Point',
                coordinates: [itemLng, itemLat],
              },
              rating: null,
              lastSynced: new Date(),
            });
          }
        }
      }
    } catch (err) {
      clearTimeout(timeoutId);
      console.warn(`[Nominatim POI] Query "${param}" notice: ${err.message}`);
    }
  });

  await Promise.all(queryPromises);

  const elapsedMs = Date.now() - startTime;
  if (excludedCount.length > 0) {
    console.log(`[Nominatim POI] 🛡️ Filtered out ${excludedCount.length} student/collegiate accommodation(s) from Hotels: ${excludedCount.join(', ')}`);
  }
  console.log(`[Nominatim POI] ✅ Success! Retrieved ${collectedPois.length} verified places in ${elapsedMs}ms`);

  return collectedPois;
};

module.exports = {
  queryNominatim,
  CATEGORY_SEARCH_PARAMS,
};
