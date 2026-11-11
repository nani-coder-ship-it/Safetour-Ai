/**
 * Overpass API Client
 * Queries OpenStreetMap data via the Overpass QL API with deep coverage for:
 * - Budget accommodations, lodges, homestays, guest houses, motels, resorts & hotels
 * - Tourist destinations, historic forts, monuments, viewpoints, parks & temples
 * - Local eateries, cafes, transit hubs, and emergency services
 *
 * Excludes student hostels, college dormitories, and campus accommodations from Hotels & Lodges.
 */

const OVERPASS_TIMEOUT_SECONDS = 15;

/**
 * Enhanced mapping of SafeTour POI types to OpenStreetMap (OSM) tag filters.
 * Note: dormitory and student hostels are strictly excluded from 'hotel'.
 */
const OSM_TYPE_TAG_MAP = {
  hotel: [
    '["tourism"~"^(hotel|guest_house|motel|resort|lodge|hostel)$"]',
    '["building"="hotel"]["tourism"]',
  ],
  hospital: [
    '["amenity"~"^(hospital|clinic|doctors)$"]',
    '["healthcare"~"^(hospital|clinic|doctor)$"]',
  ],
  pharmacy: [
    '["amenity"="pharmacy"]',
    '["healthcare"="pharmacy"]',
    '["shop"="chemist"]',
  ],
  police: [
    '["amenity"="police"]',
    '["emergency"="police"]',
  ],
  restaurant: [
    '["amenity"~"^(restaurant|cafe|fast_food|food_court|canteen|ice_cream|pub|bar)$"]',
    '["shop"~"^(bakery|pastry|confectionery)$"]',
    '["name"~"(Hotel|Mess|Canteen|Bhavan|Kitchen|Bakery|Cafe|Tea|Tiffin)",i]',
  ],
  atm: [
    '["amenity"="atm"]',
  ],
  bank: [
    '["amenity"="bank"]',
  ],
  petrol_pump: [
    '["amenity"~"^(fuel|charging_station)$"]',
  ],
  toilet: [
    '["amenity"="toilets"]',
  ],
  bus_stop: [
    '["highway"="bus_stop"]',
    '["amenity"="bus_station"]',
    '["amenity"="taxi"]',
  ],
  railway_station: [
    '["railway"~"^(station|halt)$"]',
  ],
  shopping: [
    '["shop"~"^(mall|department_store|clothes|boutique|general)$"]',
  ],
  supermarket: [
    '["shop"~"^(supermarket|convenience|grocery)$"]',
  ],
  college: [
    '["amenity"="college"]',
  ],
  university: [
    '["amenity"="university"]',
  ],
  tourist_spot: [
    '["tourism"~"^(attraction|viewpoint|museum|gallery|theme_park|zoo|aquarium|artwork|picnic_site)$"]',
    '["historic"~"^(monument|memorial|castle|ruins|fort|archaeological_site|heritage|city_gate|palace|tomb|wayside_shrine|monastery)$"]',
    '["leisure"~"^(park|garden|nature_reserve|water_park)$"]',
    '["amenity"="place_of_worship"]',
    '["natural"~"^(beach|waterfall|peak|spring|cave_entrance)$"]',
    '["name"~"(Temple|Kovil|Koil|Amman|Murugan|Perumal|Sivan|Church|Mosque|Dargah|Falls|Dam)",i]',
  ],
};

/**
 * Classifies whether a place is educational, campus, or student accommodation.
 * Used to prevent student hostels from being displayed under "Hotels & Lodges".
 */
const isStudentAccommodation = (name = '', tags = {}) => {
  const n = (name || '').toLowerCase();
  const t = (tags.tourism || '').toLowerCase();
  const b = (tags.building || '').toLowerCase();
  const a = (tags.amenity || '').toLowerCase();
  const s = (tags.student || '').toLowerCase();
  const acc = (tags.accommodation || '').toLowerCase();
  const op = (tags.operator || '').toLowerCase();
  let addr = '';
  if (typeof tags.address === 'string') {
    addr = tags.address.toLowerCase();
  } else if (tags.address && typeof tags.address === 'object') {
    addr = Object.values(tags.address).filter(v => typeof v === 'string').join(' ').toLowerCase();
  } else if (tags['addr:full'] || tags['addr:street']) {
    addr = `${tags['addr:full'] || ''} ${tags['addr:street'] || ''}`.toLowerCase();
  }

  // 1. Explicit OSM tags for dormitory / student housing
  if (b === 'dormitory' || a === 'dormitory' || s === 'yes' || acc === 'student') {
    return true;
  }

  // 2. Specific student / collegiate hostel naming patterns
  const studentPatterns = [
    'mens hostel', "men's hostel", 'womens hostel', "women's hostel",
    'ladies hostel', 'gents hostel', "gent's hostel",
    'boys hostel', "boy's hostel", 'girls hostel', "girl's hostel",
    'student hostel', 'student accommodation', 'college hostel', 'university hostel',
    'campus hostel', 'scholars hostel', 'hostel block', 'hall of residence',
    'nelson mandela', 'kalam hostel', 'bose hostel', 'tagore hostel',
    'dormitory', 'dorm block', 'student housing', 'college mess', 'student mess',
    'hostel mess', 'pg for gents', 'pg for ladies', 'pg for boys', 'pg for girls',
  ];

  for (const pattern of studentPatterns) {
    if (n.includes(pattern) || addr.includes(pattern)) {
      return true;
    }
  }

  // 3. Educational operator or context check
  const eduKeywords = [
    'college', 'university', 'school', 'institute', 'campus', 'klu',
    'polytechnic', 'academy', 'department', 'faculty', 'hostel campus'
  ];

  if (eduKeywords.some((keyword) => op.includes(keyword) || n.includes(keyword) || addr.includes(keyword))) {
    const residentKeywords = ['hostel', 'dorm', 'residence', 'block', 'mess', 'hall', 'room', 'living', 'quarters'];
    if (residentKeywords.some((rk) => n.includes(rk) || addr.includes(rk) || t === 'hostel')) {
      return true;
    }
    if (
      n.includes('college') ||
      n.includes('university') ||
      n.includes('campus') ||
      n.includes('department') ||
      n.includes('school of') ||
      n.includes('faculty of') ||
      n.includes('institute of')
    ) {
      return true;
    }
  }

  return false;
};

/**
 * Builds the Overpass QL query string for a given location, radius, and type.
 * Uses indexed [bbox:s,w,n,e] header to achieve sub-second query performance without full-table way scans.
 */
const buildOverpassQuery = (lat, lng, radiusMeters, type) => {
  const tagFilters = OSM_TYPE_TAG_MAP[type];
  if (!tagFilters) {
    throw new Error(`Unsupported POI type: ${type}`);
  }

  // 1 degree latitude ~= 111,000 meters
  const deltaLat = (radiusMeters / 111000) * 1.08;
  const deltaLng = (radiusMeters / (111000 * Math.cos((lat * Math.PI) / 180))) * 1.08;

  const s = (lat - deltaLat).toFixed(5);
  const w = (lng - deltaLng).toFixed(5);
  const n = (lat + deltaLat).toFixed(5);
  const e = (lng + deltaLng).toFixed(5);

  // Filter nodes and ways within spatial bbox
  const statements = tagFilters
    .map((filter) => `  node${filter};\n  way${filter};`)
    .join('\n');

  return `
[out:json][timeout:${OVERPASS_TIMEOUT_SECONDS}][maxsize:268435456][bbox:${s},${w},${n},${e}];
(
${statements}
);
out center 60;
`.trim();
};

/**
 * Resolves a precise subType for fine-grained categorization and filtering
 */
const resolvePoiSubType = (tags, type, name = '') => {
  if (!tags) return type;
  const n = (name || '').toLowerCase();

  if (type === 'hotel') {
    if (tags.tourism === 'lodge' || tags.building === 'lodge' || n.includes('lodge') || n.includes('nivas') || n.includes('mansion') || n.includes('bhavan') || n.includes('residency')) return 'lodge';
    if (tags.tourism === 'guest_house' || tags.building === 'guest_house' || tags.amenity === 'guest_house' || n.includes('guest house')) return 'guest_house';
    if (tags.tourism === 'homestay' || n.includes('homestay') || n.includes('home stay')) return 'homestay';
    if (tags.tourism === 'resort' || n.includes('resort')) return 'resort';
    if (tags.tourism === 'motel' || n.includes('motel')) return 'motel';
    if (tags.tourism === 'bed_and_breakfast' || n.includes('b&b') || n.includes('bed and breakfast')) return 'bed_and_breakfast';
    if (tags.amenity === 'dharamshala' || tags.tourism === 'dharamshala' || n.includes('dharamshala') || n.includes('dharmashala')) return 'dharamshala';
    if (tags.amenity === 'choultry' || n.includes('choultry')) return 'choultry';
    if (tags.tourism === 'hostel' && !isStudentAccommodation(name, tags)) return 'tourist_hostel';
    return 'hotel';
  }

  if (type === 'restaurant') {
    if (tags.amenity === 'cafe' || n.includes('cafe') || n.includes('coffee')) return 'cafe';
    if (tags.amenity === 'fast_food' || n.includes('fast food') || n.includes('burger') || n.includes('pizza')) return 'fast_food';
    if (tags.shop === 'bakery' || tags.shop === 'pastry' || n.includes('bakery') || n.includes('bakes')) return 'bakery';
    if (tags.amenity === 'food_court' || n.includes('food court')) return 'food_court';
    return 'restaurant';
  }

  if (type === 'tourist_spot') {
    if (tags.amenity === 'place_of_worship' || tags.historic === 'wayside_shrine' || tags.historic === 'monastery' || n.includes('temple') || n.includes('mandir') || n.includes('kovil') || n.includes('church') || n.includes('mosque') || n.includes('masjid') || n.includes('shrine') || n.includes('gurudwara')) return 'temple';
    if (tags.historic === 'fort' || tags.historic === 'castle' || tags.historic === 'ruins' || n.includes('fort') || n.includes('castle') || n.includes('palace') || tags.historic === 'palace') return 'fort';
    if (tags.tourism === 'viewpoint' || n.includes('viewpoint') || n.includes('point') || n.includes('sunset') || n.includes('sunrise') || n.includes('hill')) return 'viewpoint';
    if (tags.natural === 'waterfall' || n.includes('waterfall') || n.includes('falls')) return 'waterfall';
    if (tags.natural === 'beach' || n.includes('beach')) return 'beach';
    if (tags.tourism === 'museum' || tags.tourism === 'gallery' || n.includes('museum') || n.includes('gallery')) return 'museum';
    if (tags.historic === 'monument' || tags.historic === 'memorial' || tags.historic === 'heritage' || tags.historic === 'archaeological_site') return 'monument';
    if (tags.leisure === 'park' || tags.leisure === 'garden' || tags.leisure === 'nature_reserve' || n.includes('park') || n.includes('garden')) return 'park';
    if (tags.tourism === 'theme_park' || tags.tourism === 'zoo' || tags.tourism === 'aquarium' || n.includes('zoo')) return 'zoo';
    return 'attraction';
  }

  if (type === 'hospital') {
    if (tags.amenity === 'pharmacy' || tags.healthcare === 'pharmacy' || n.includes('pharmacy') || n.includes('chemist') || n.includes('medical')) return 'pharmacy';
    if (tags.amenity === 'clinic' || tags.healthcare === 'clinic' || n.includes('clinic')) return 'clinic';
    return 'hospital';
  }

  return type;
};

/**
 * Resolves address string from OSM address tags
 */
const resolveAddress = (tags) => {
  if (!tags) return 'Address unavailable';
  const parts = [];
  if (tags['addr:housenumber']) parts.push(tags['addr:housenumber']);
  if (tags['addr:street']) parts.push(tags['addr:street']);
  if (tags['addr:suburb'] || tags['addr:neighbourhood']) parts.push(tags['addr:suburb'] || tags['addr:neighbourhood']);
  if (tags['addr:city'] || tags['addr:town'] || tags['addr:village']) parts.push(tags['addr:city'] || tags['addr:town'] || tags['addr:village']);
  if (tags['addr:postcode']) parts.push(tags['addr:postcode']);
  if (parts.length > 0) return parts.join(', ');
  if (tags['addr:full']) return tags['addr:full'];
  return 'Address unavailable';
};

/**
 * Formats a clean, descriptive name from OSM tags.
 * Requirement 12: Never invent fake placeholder names like "Nearby Hotel" or "Local Restaurant".
 */
const resolvePoiName = (tags, type) => {
  if (!tags) return null;

  const directName =
    tags.name ||
    tags['name:en'] ||
    tags.alt_name ||
    tags.loc_name ||
    tags.official_name ||
    tags.brand ||
    tags.operator;

  if (directName && directName.trim().length > 0) {
    return directName.trim();
  }

  return null;
};

const OVERPASS_ENDPOINTS = [
  {
    name: 'Overpass Primary (overpass-api.de)',
    url: 'https://overpass-api.de/api/interpreter',
    timeoutMs: 6000,
  },
  {
    name: 'Overpass Kumi Systems',
    url: 'https://overpass.kumi.systems/api/interpreter',
    timeoutMs: 6000,
  },
  {
    name: 'Overpass Private Coffee',
    url: 'https://overpass.private.coffee/api/interpreter',
    timeoutMs: 6000,
  },
];

class OverpassTimeoutError extends Error {
  constructor(message = 'Overpass API request timed out') {
    super(message);
    this.name = 'OverpassTimeoutError';
    this.isTimeout = true;
  }
}

class OverpassQueryError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.name = 'OverpassQueryError';
    this.statusCode = statusCode;
  }
}

/**
 * Query an individual Overpass endpoint with a strict timeout and correct content negotiation
 */
const fetchFromEndpoint = async (endpoint, query) => {
  const startTime = Date.now();
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), endpoint.timeoutMs);

  const params = new URLSearchParams();
  params.append('data', query);

  try {
    const response = await fetch(endpoint.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json, */*',
        // Explicitly avoid zstd encoding so Apache won't return 406 Not Acceptable
        'Accept-Encoding': 'gzip, deflate',
        'User-Agent': 'SafeTourAI-Backend/1.1 (https://safetour.ai)',
      },
      body: params,
      signal: controller.signal,
    });

    clearTimeout(timeoutId);
    const elapsedMs = Date.now() - startTime;

    if (!response.ok) {
      const errorBody = await response.text().catch(() => '');
      throw new OverpassQueryError(
        `${endpoint.name} HTTP ${response.status}: ${errorBody.slice(0, 150)}`,
        response.status
      );
    }

    const json = await response.json();
    return { json, elapsedMs };
  } catch (err) {
    clearTimeout(timeoutId);
    const elapsedMs = Date.now() - startTime;
    if (err.name === 'AbortError') {
      throw new OverpassTimeoutError(`${endpoint.name} timed out after ${elapsedMs}ms`);
    }
    throw err;
  }
};

/**
 * Query Overpass API with multi-mirror automatic fallback
 */
const queryOverpass = async (lat, lng, radiusMeters = 3000, type) => {
  const query = buildOverpassQuery(lat, lng, radiusMeters, type);
  console.log(`\n=================== [OVERPASS QUERY DETAILS] ===================`);
  console.log(`POI Type: "${type}" | Search Radius: ${radiusMeters}m | Center: (${lat}, ${lng})`);
  console.log(`Exact Overpass QL Query Sent to Mirrors:\n${query}`);
  console.log(`===============================================================\n`);
  const queryStartTime = Date.now();

  let lastError = null;
  let rawJson = null;
  let successfulEndpoint = null;

  for (const endpoint of OVERPASS_ENDPOINTS) {
    try {
      const result = await fetchFromEndpoint(endpoint, query);
      rawJson = result.json;
      successfulEndpoint = endpoint.name;
      break;
    } catch (err) {
      lastError = err;
      console.warn(`[Overpass API] ⚠️ ${endpoint.name} notice (${err.message}). Trying fallback mirror...`);
    }
  }

  if (!rawJson) {
    console.warn(`[Overpass API] All Overpass mirrors returned without results or timed out.`);
    return [];
  }

  const json = rawJson;
  if (!json.elements || !Array.isArray(json.elements)) {
    return [];
  }

  const pois = [];
  const seenOsmIds = new Set();
  const excludedHostels = [];

  for (const element of json.elements) {
    const elementLat = element.lat || element.center?.lat;
    const elementLng = element.lon || element.center?.lon;

    if (typeof elementLat !== 'number' || typeof elementLng !== 'number') {
      continue;
    }

    const osmId = `${element.type}/${element.id}`;
    if (seenOsmIds.has(osmId)) continue;
    seenOsmIds.add(osmId);

    const tags = element.tags || {};
    const name = resolvePoiName(tags, type);

    // Requirement 12: Do not invent fake places. Must have a real name.
    if (!name || name.trim().length === 0) {
      continue;
    }

    // CRITICAL: Filter student / collegiate hostels from Hotels & Lodges
    if (type === 'hotel' && isStudentAccommodation(name, tags)) {
      excludedHostels.push(name);
      continue;
    }

    const subType = resolvePoiSubType(tags, type, name);
    const address = resolveAddress(tags);
    const phone = tags.phone || tags['contact:phone'] || tags['contact:mobile'] || null;
    const website = tags.website || tags['contact:website'] || tags.url || null;

    pois.push({
      osmId,
      name,
      type,
      subType,
      address,
      phone,
      website,
      lat: elementLat,
      lng: elementLng,
      location: {
        type: 'Point',
        coordinates: [elementLng, elementLat],
      },
      rating: tags.stars ? parseFloat(tags.stars) : null,
      lastSynced: new Date(),
    });
  }

  if (excludedHostels.length > 0) {
    console.log(`[Overpass API] 🛡️ Excluded ${excludedHostels.length} student/collegiate accommodation(s) from Hotels: ${excludedHostels.join(', ')}`);
  }

  const totalDuration = Date.now() - queryStartTime;
  console.log(`[Overpass API] ✅ Retrieved ${pois.length} verified POIs from ${successfulEndpoint} in ${totalDuration}ms`);
  return pois;
};

module.exports = {
  queryOverpass,
  isStudentAccommodation,
  OverpassTimeoutError,
  OverpassQueryError,
  OSM_TYPE_TAG_MAP,
  resolvePoiSubType,
  resolveAddress,
};
