const POI = require('./poi.model');
const mongoose = require('mongoose');
const { queryOverpass, isStudentAccommodation } = require('./overpass.client');
const { queryNominatim } = require('./nominatim.client');
const { queryMapTiler } = require('./maptiler.client');

// Freshness threshold: 7 days
const CACHE_TTL_DAYS = 7;
// High-quality discovery threshold: If cached results are fewer than 15, query live providers
const MIN_CACHE_THRESHOLD = 15;

/**
 * Calculates the exact great-circle distance between two points using the Haversine formula (in meters).
 */
const calculateHaversineDistanceMeters = (lat1, lon1, lat2, lon2) => {
  const R = 6371000; // Earth radius in meters
  const toRad = (x) => (x * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

/**
 * Get nearby POIs of a specified type within radiusMeters.
 * Checks local MongoDB cache. If insufficient (< 15 places), queries MapTiler, Overpass, and Nominatim concurrently,
 * filters student hostels, calculates exact distances, deduplicates, and sorts ascending by distance.
 *
 * @param {number} lat - Latitude
 * @param {number} lng - Longitude
 * @param {number} radiusMeters - Search radius in meters
 * @param {string} type - POI type enum
 * @param {Object} [options] - Optional filters: subType, search
 * @returns {Promise<Array>} List of POI documents sorted by distance
 */
const getNearby = async (lat, lng, radiusMeters = 3000, type, options = {}) => {
  const numericLat = parseFloat(lat);
  const numericLng = parseFloat(lng);
  const numericRadius = Math.min(Math.max(parseInt(radiusMeters, 10) || 3000, 100), 25000); // up to 25km
  const { subType, search } = options;

  if (isNaN(numericLat) || isNaN(numericLng)) {
    throw new Error('Valid latitude and longitude coordinates are required.');
  }

  console.log(`\n=================== [POI SEARCH REQUEST] ===================`);
  console.log(`Current location: lat=${numericLat}, lng=${numericLng}`);
  console.log(`Selected category: ${type}`);
  console.log(`Selected radius: ${numericRadius}m (${(numericRadius / 1000).toFixed(1)} km)`);
  if (subType) console.log(`Selected subType: ${subType}`);
  if (search) console.log(`Search query: "${search}"`);
  console.log(`============================================================`);

  const sevenDaysAgo = new Date(Date.now() - CACHE_TTL_DAYS * 24 * 60 * 60 * 1000);

  // 1. Check local MongoDB cache using 2dsphere spatial index (only if DB is connected)
  let cachedResults = [];
  if (mongoose.connection && mongoose.connection.readyState === 1) {
    try {
      const regionalLookupDist = Math.max(numericRadius * 2, 14000);
      cachedResults = await POI.find({
        type,
        $or: [
          { osmId: /^seed\// },
          { lastSynced: { $gte: sevenDaysAgo } },
        ],
        location: {
          $near: {
            $geometry: {
              type: 'Point',
              coordinates: [numericLng, numericLat],
            },
            $maxDistance: regionalLookupDist,
          },
        },
      }).limit(60).lean();
    } catch (geoErr) {
      console.warn('[POI Service] MongoDB cache lookup notice:', geoErr.message);
    }
  } else {
    console.log('[POI Service] MongoDB is disconnected or buffering, skipping DB cache to query live providers immediately.');
  }

  const placesWithinRadius = cachedResults.filter((p) => {
    const pLat = p.lat || p.location?.coordinates?.[1];
    const pLng = p.lng || p.location?.coordinates?.[0];
    if (typeof pLat !== 'number' || typeof pLng !== 'number') return false;
    return calculateHaversineDistanceMeters(numericLat, numericLng, pLat, pLng) <= numericRadius;
  });

  console.log(`[POI Service] Cached places found in MongoDB: ${cachedResults.length} (${placesWithinRadius.length} within ${numericRadius}m)`);

  let freshPois = [];

  // 2. If places strictly within requested radius is low, query fast live POI provider first
  if (placesWithinRadius.length < 3 || options.forceRefresh) {
    console.log(`[POI Service] Places within radius (${placesWithinRadius.length}) is below threshold (3). Querying fast MapTiler provider (<200ms)...`);

    // Priority 1: MapTiler is ultra-fast (<200ms) and authoritative
    const maptilerPois = await queryMapTiler(numericLat, numericLng, numericRadius, type).catch((err) => {
      console.warn(`[POI Service] MapTiler notice: ${err.message}`);
      return [];
    });

    freshPois.push(...maptilerPois);

    // If MapTiler gave sufficient results (>= 3), return immediately to mobile user!
    // Run Overpass asynchronously in background to enrich cache without stalling the user.
    if (freshPois.length < 3) {
      console.log(`[POI Service] MapTiler returned ${freshPois.length} places. Querying Overpass & Nominatim with 2s ceiling...`);
      const fallbackPromises = [
        queryOverpass(numericLat, numericLng, numericRadius, type).catch(() => []),
        queryNominatim(numericLat, numericLng, numericRadius, type).catch(() => []),
      ];

      const results = await Promise.allSettled(
        fallbackPromises.map((p) =>
          Promise.race([
            p,
            new Promise((resolve) => setTimeout(() => resolve([]), 2000)),
          ])
        )
      );

      for (const res of results) {
        if (res.status === 'fulfilled' && Array.isArray(res.value)) {
          freshPois.push(...res.value);
        }
      }
    } else {
      // Background enrichment: Sync Overpass into DB without blocking user
      queryOverpass(numericLat, numericLng, numericRadius, type)
        .then((bgPois) => {
          if (bgPois && bgPois.length > 0 && mongoose.connection && mongoose.connection.readyState === 1) {
            const bulkOps = bgPois.map((p) => ({
              updateOne: { filter: { osmId: p.osmId }, update: { $set: p }, upsert: true },
            }));
            POI.bulkWrite(bulkOps, { ordered: false }).catch(() => {});
          }
        })
        .catch(() => {});
    }

    console.log(`\n--- [PROVIDER RESULTS BREAKDOWN] ---`);
    console.log(`MapTiler returned: ${maptilerPois.length} places`);
    console.log(`Total raw fresh places gathered: ${freshPois.length}`);
    console.log(`------------------------------------\n`);

    // Upsert fresh places into MongoDB in background only if DB is connected
    if (freshPois.length > 0 && mongoose.connection && mongoose.connection.readyState === 1) {
      const bulkOps = freshPois.map((poi) => ({
        updateOne: {
          filter: { osmId: poi.osmId },
          update: { $set: poi },
          upsert: true,
        },
      }));

      POI.bulkWrite(bulkOps, { ordered: false })
        .then(() => console.log(`[POI Service] Synced ${freshPois.length} places into MongoDB cache`))
        .catch((bulkError) => console.warn('[POI Service] Bulk write notice:', bulkError.message));
    }
  }

  // 3. Combine in-memory fresh places with existing database records
  const candidateMap = new Map();
  for (const p of freshPois) {
    const id = p.osmId || `coord_${p.lat}_${p.lng}`;
    candidateMap.set(id, p);
  }
  for (const p of cachedResults) {
    const id = p.osmId || `coord_${p.lat}_${p.lng}`;
    if (!candidateMap.has(id)) {
      candidateMap.set(id, p);
    }
  }
  const candidatePlaces = Array.from(candidateMap.values());
  console.log(`[POI Service] Raw candidates pool before filtering: ${candidatePlaces.length} places`);

  // 4. In-memory Deduplication, Filtering, and Haversine Distance Calculation
  const finalPlaces = [];
  const seenOsmIds = new Set();
  const excludedLog = [];

  for (const place of candidatePlaces) {
    const pLat = place.lat || place.location?.coordinates?.[1];
    const pLng = place.lng || place.location?.coordinates?.[0];

    if (typeof pLat !== 'number' || typeof pLng !== 'number') continue;

    // Requirement 3 & 20: Validate and exclude student / collegiate accommodations
    if (isStudentAccommodation(place.name, place)) {
      excludedLog.push({ name: place.name, reason: 'Collegiate / Student Accommodation' });
      continue;
    }

    // Strict qualification check: If type is 'hotel', place MUST be an actual travel accommodation
    if (type === 'hotel') {
      const allowedHotelSubTypes = ['hotel', 'guest_house', 'motel', 'hostel', 'resort', 'lodge', 'chalet', 'apartment', 'bed_and_breakfast', 'tourist_hostel', 'tourism'];
      const st = (place.subType || '').toLowerCase();
      const n = (place.name || '').toLowerCase();
      if (
        st === 'canteen' || st === 'restaurant' || st === 'fast_food' || st === 'cafe' || st === 'bakery' || st === 'amenity' || st === 'building' ||
        /\b(canteen|mess|biriyani|bakes|bakery|tea stall|juice|eatery)\b/i.test(n) ||
        (place.subType && !allowedHotelSubTypes.includes(st) && !/\b(hotel|lodge|resort|guest house|homestay|motel|inn|stay)\b/i.test(n))
      ) {
        excludedLog.push({ name: place.name, reason: 'Food establishment/canteen/building cannot qualify under Hotel category' });
        continue;
      }
      if (place.subType === 'tourism') {
        place.subType = /\blodge\b/i.test(n) ? 'lodge' : (/\bresort\b/i.test(n) ? 'resort' : 'hotel');
      }
    }

    // Requirement 12: Exclude roads, highways, and administrative regions
    const lowerName = (place.name || '').toLowerCase();
    if (
      /\b(road|salai|highway|expressway|junction|cross|bypass|constituency|taluk|district|ward)\b/i.test(lowerName) ||
      place.subType === 'highway' ||
      place.subType === 'boundary' ||
      place.subType === 'administrative'
    ) {
      continue;
    }

    // Optional subType filter
    if (subType && subType !== 'all' && place.subType !== subType) {
      continue;
    }

    // Optional text search filter
    if (search && search.trim().length > 0) {
      const q = search.trim().toLowerCase();
      const placeMatch =
        (place.name && place.name.toLowerCase().includes(q)) ||
        (place.address && place.address.toLowerCase().includes(q)) ||
        (place.subType && place.subType.toLowerCase().includes(q));
      if (!placeMatch) continue;
    }

    // Calculate exact Haversine distance from user's GPS search origin
    const distanceMeters = Math.round(calculateHaversineDistanceMeters(numericLat, numericLng, pLat, pLng));

    // Strict radius validation
    if (distanceMeters > numericRadius) {
      continue;
    }

    // Deduplicate by OSM ID or normalized name + proximity (< 80 meters)
    const normName = (place.name || '').toLowerCase().replace(/[^a-z0-9]/g, '');
    let isDupe = false;

    if (place.osmId && seenOsmIds.has(place.osmId)) {
      isDupe = true;
    } else {
      for (const existing of finalPlaces) {
        if (normName.length > 2 && normName === existing.normName && Math.abs(distanceMeters - existing.distance) < 80) {
          isDupe = true;
          break;
        }
      }
    }

    if (!isDupe) {
      if (place.osmId) seenOsmIds.add(place.osmId);
      finalPlaces.push({
        _id: place._id,
        osmId: place.osmId || `custom_${pLat}_${pLng}`,
        name: place.name,
        normName,
        type: place.type,
        subType: place.subType || type,
        address: place.address || 'Address unavailable',
        phone: place.phone || null,
        website: place.website || null,
        lat: pLat,
        lng: pLng,
        rating: place.rating || null,
        distance: distanceMeters,
      });
    }
  }

  // Requirement 11: Search fallback if 0 places within selected radius (disabled for hotel to enforce honest empty state)
  if (type !== 'hotel' && finalPlaces.length === 0 && candidatePlaces.length > 0) {
    const fallbackRadius = Math.min(Math.max(numericRadius * 1.8, 6000), 12000);
    console.log(`[POI Fallback] 0 places within strict ${numericRadius}m. Expanding to ${fallbackRadius}m fallback radius...`);

    for (const place of candidatePlaces) {
      const pLat = place.lat || place.location?.coordinates?.[1];
      const pLng = place.lng || place.location?.coordinates?.[0];
      if (typeof pLat !== 'number' || typeof pLng !== 'number') continue;
      if (isStudentAccommodation(place.name, place)) continue;

      // Strict check: Fallback MUST NEVER substitute canteens, restaurants, or generic buildings for hotels
      if (type === 'hotel') {
        const allowedHotelSubTypes = ['hotel', 'guest_house', 'motel', 'hostel', 'resort', 'lodge', 'chalet', 'apartment', 'bed_and_breakfast', 'tourist_hostel'];
        const st = (place.subType || '').toLowerCase();
        const n = (place.name || '').toLowerCase();
        if (
          st === 'canteen' || st === 'restaurant' || st === 'fast_food' || st === 'cafe' || st === 'bakery' || st === 'amenity' || st === 'building' ||
          /\b(canteen|mess|biriyani|bakes|bakery|tea stall|juice|eatery)\b/i.test(n) ||
          (place.subType && !allowedHotelSubTypes.includes(st))
        ) {
          continue;
        }
      }

      const distanceMeters = Math.round(calculateHaversineDistanceMeters(numericLat, numericLng, pLat, pLng));
      if (distanceMeters <= fallbackRadius) {
        const placeId = place.osmId || `fallback_${pLat}_${pLng}`;
        if (!seenOsmIds.has(placeId)) {
          seenOsmIds.add(placeId);
          finalPlaces.push({
            _id: place._id,
            osmId: placeId,
            name: place.name,
            normName: (place.name || '').toLowerCase().replace(/[^a-z0-9]/g, ''),
            type: place.type,
            subType: place.subType || type,
            address: place.address || 'Address unavailable',
            phone: place.phone || null,
            website: place.website || null,
            lat: pLat,
            lng: pLng,
            rating: place.rating || null,
            distance: distanceMeters,
          });
        }
      }
    }
  }

  // 5. Sort ascending by distance (nearest first)
  finalPlaces.sort((a, b) => a.distance - b.distance);

  // Requirement 21: Log debugging details
  console.log(`\n=================== [POI FILTERING REPORT] ===================`);
  console.log(`Raw candidates: ${candidatePlaces.length}`);
  console.log(`Excluded places count: ${excludedLog.length}`);
  if (excludedLog.length > 0) {
    excludedLog.forEach((ex) => console.log(`   ❌ Excluded: "${ex.name}" | Reason: ${ex.reason}`));
  }
  console.log(`Final validated results: ${finalPlaces.length} places (within ${numericRadius}m)`);
  finalPlaces.slice(0, 8).forEach((p, idx) => {
    const dStr = p.distance < 1000 ? `${p.distance}m` : `${(p.distance / 1000).toFixed(1)}km`;
    console.log(`   ${idx + 1}. "${p.name}" (${dStr}) [${p.subType}]`);
  });
  console.log(`==============================================================\n`);

  // Cap at 40 high-relevance places
  return finalPlaces.slice(0, 40);
};

/**
 * Search places by free-form text query using Nominatim + local POI database
 *
 * @param {string} query - Free text search (e.g. 'Nellore', 'hotel', 'hospital', 'temple')
 * @param {number} [lat] - Optional user latitude for proximity bias
 * @param {number} [lng] - Optional user longitude for proximity bias
 * @returns {Promise<Array>} List of matching places with coordinates
 */
const searchPlaces = async (query, lat, lng) => {
  if (!query || query.trim().length === 0) return [];
  const cleanQ = query.trim();

  // 1. Search local cached POIs
  const localQuery = {
    $or: [
      { name: { $regex: cleanQ, $options: 'i' } },
      { address: { $regex: cleanQ, $options: 'i' } },
      { subType: { $regex: cleanQ, $options: 'i' } },
    ],
  };

  let localMatches = [];
  try {
    localMatches = await POI.find(localQuery).limit(10).lean();
  } catch (err) {
    console.warn('[POI Service] Local search error:', err.message);
  }

  const results = localMatches.map((item) => ({
    osmId: item.osmId,
    name: item.name,
    displayName: item.address ? `${item.name}, ${item.address}` : item.name,
    lat: item.lat,
    lng: item.lng,
    type: item.type,
    subType: item.subType,
  }));

  // 2. Query OSM Nominatim Geocoding API for global places, cities, landmarks
  try {
    let nominatimUrl = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(cleanQ)}&limit=10&addressdetails=1`;
    if (lat && lng && !isNaN(parseFloat(lat)) && !isNaN(parseFloat(lng))) {
      const delta = 0.5; // ~50km bounding box
      nominatimUrl += `&viewbox=${parseFloat(lng) - delta},${parseFloat(lat) + delta},${parseFloat(lng) + delta},${parseFloat(lat) - delta}`;
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 6000);

    const response = await fetch(nominatimUrl, {
      headers: {
        'User-Agent': 'SafeTourAI-Backend/1.2 (safetour-contact@example.com)',
        'Accept-Language': 'en',
      },
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (response.ok) {
      const data = await response.json();
      if (Array.isArray(data)) {
        for (const item of data) {
          const itemLat = parseFloat(item.lat);
          const itemLng = parseFloat(item.lon);
          const osmId = `${item.osm_type || 'node'}/${item.osm_id}`;

          if (!results.some((r) => r.osmId === osmId || (Math.abs(r.lat - itemLat) < 0.0001 && Math.abs(r.lng - itemLng) < 0.0001))) {
            const shortName = item.name || (item.display_name ? item.display_name.split(',')[0].trim() : cleanQ);
            results.push({
              osmId,
              name: shortName,
              displayName: item.display_name,
              lat: itemLat,
              lng: itemLng,
              type: item.type || item.class || 'place',
              subType: item.class || 'landmark',
            });
          }
        }
      }
    }
  } catch (nomErr) {
    console.warn('[POI Service] Nominatim geocode error:', nomErr.message);
  }

  return results.slice(0, 15);
};

module.exports = {
  getNearby,
  searchPlaces,
  calculateHaversineDistanceMeters,
};
