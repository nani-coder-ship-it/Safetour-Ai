/**
 * MapTiler POI Search & Geocoding Client
 * Fast (<200ms), authoritative POI discovery using MapTiler Cloud with proximity biasing.
 */

const { isStudentAccommodation } = require('./overpass.client');

const MAPTILER_API_KEY = process.env.MAPTILER_API_KEY || '';
const MAPTILER_BASE_URL = 'https://api.maptiler.com/geocoding';

const MAPTILER_CATEGORY_QUERIES = {
  hotel: ['hotel', 'lodge', 'resort', 'guest house'],
  restaurant: ['restaurant', 'cafe', 'fast food', 'bakery'],
  tourist_spot: ['temple', 'attraction', 'monument', 'park', 'shrine', 'viewpoint'],
  hospital: ['hospital', 'clinic'],
  pharmacy: ['pharmacy', 'chemist'],
  police: ['police'],
  atm: ['atm', 'bank'],
  bank: ['bank'],
  petrol_pump: ['petrol pump', 'gas station'],
  bus_stop: ['bus station', 'bus stop'],
  railway_station: ['railway station'],
  shopping: ['shopping mall', 'retail'],
  supermarket: ['supermarket', 'grocery'],
  college: ['college', 'university'],
  toilet: ['public toilet', 'restroom'],
};

/**
 * Query MapTiler for POIs around coordinates biased by proximity.
 *
 * @param {number} lat - User latitude
 * @param {number} lng - User longitude
 * @param {number} radiusMeters - Search radius in meters
 * @param {string} type - SafeTour POI category
 * @returns {Promise<Array>} List of validated POI objects
 */
const queryMapTiler = async (lat, lng, radiusMeters = 3000, type) => {
  const queries = MAPTILER_CATEGORY_QUERIES[type] || [type];
  const results = [];
  const seenIds = new Set();
  const startTime = Date.now();

  console.log(`\n=================== [MAPTILER QUERY DETAILS] ===================`);
  console.log(`POI Type: "${type}" | Center Proximity: (${lng}, ${lat})`);
  console.log(`MapTiler Category Search Queries: ${JSON.stringify(queries.slice(0, 3))}`);
  queries.slice(0, 3).forEach((q, idx) => console.log(`   Query #${idx + 1}: ${MAPTILER_BASE_URL}/${encodeURIComponent(q)}.json?proximity=${lng},${lat}&limit=10`));
  console.log(`================================================================\n`);

  // Run top queries in parallel with 3s timeout
  const promises = queries.slice(0, 3).map(async (query) => {
    const url = `${MAPTILER_BASE_URL}/${encodeURIComponent(query)}.json?key=${MAPTILER_API_KEY}&proximity=${lng},${lat}&limit=10`;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3500);

    try {
      const response = await fetch(url, { signal: controller.signal });
      clearTimeout(timeoutId);

      if (response.ok) {
        const data = await response.json();
        if (data.features && Array.isArray(data.features)) {
          for (const feat of data.features) {
            const coords = feat.geometry?.coordinates;
            if (!coords || coords.length < 2) continue;

            const fLng = coords[0];
            const fLat = coords[1];
            const name = feat.text || feat.place_name?.split(',')[0]?.trim();
            if (!name || name.trim().length === 0) continue;

            const placeId = feat.id || `maptiler_${fLat}_${fLng}`;
            if (seenIds.has(placeId)) continue;

            // Student accommodation exclusion across all categories
            if (isStudentAccommodation(name, feat.properties || {})) {
              continue;
            }

            // A restaurant or food place never qualifies under hotel
            if (type === 'hotel' && (feat.properties?.category === 'restaurant' || feat.properties?.category === 'food' || feat.properties?.category === 'cafe')) {
              continue;
            }

            seenIds.add(placeId);
            results.push({
              osmId: placeId,
              name: name.trim(),
              type,
              subType: feat.properties?.category || query,
              address: feat.place_name || 'Address unavailable',
              phone: null,
              website: null,
              lat: fLat,
              lng: fLng,
              location: {
                type: 'Point',
                coordinates: [fLng, fLat],
              },
              rating: null,
              lastSynced: new Date(),
            });
          }
        }
      } else {
        const errText = await response.text();
        console.warn(`[MapTiler POI] HTTP ${response.status} for query "${query}": ${errText.slice(0, 150)}`);
      }
    } catch (err) {
      clearTimeout(timeoutId);
      console.warn(`[MapTiler POI] Notice for query "${query}": ${err.message}`);
    }
  });

  await Promise.allSettled(promises);
  console.log(`[MapTiler POI] ✅ Retrieved ${results.length} places in ${Date.now() - startTime}ms`);
  return results;
};

module.exports = {
  queryMapTiler,
  MAPTILER_CATEGORY_QUERIES,
};
