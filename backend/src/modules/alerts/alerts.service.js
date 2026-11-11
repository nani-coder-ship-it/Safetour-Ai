const Alert = require('./alert.model');
const DangerZone = require('../geofence/geofence.model');
const Location = require('../location/location.model');
const geofenceService = require('../geofence/geofence.service');

/**
 * Calculates great-circle distance between two GPS coordinates in kilometers.
 */
const calculateHaversineDistanceKm = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Earth radius in km
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
 * Calculates the centroid coordinate of a DangerZone polygon.
 */
const getZoneCenter = (zone) => {
  if (!zone.polygon || !zone.polygon.coordinates || !zone.polygon.coordinates[0]) {
    return null;
  }
  const ring = zone.polygon.coordinates[0];
  let sumLng = 0;
  let sumLat = 0;
  for (const pt of ring) {
    sumLng += pt[0];
    sumLat += pt[1];
  }
  return {
    lng: sumLng / ring.length,
    lat: sumLat / ring.length,
  };
};

/**
 * Fetches real-time live weather from Open-Meteo for the user's exact GPS coordinates.
 * High-speed (<300ms), zero API key requirement, global coverage.
 */
const fetchRealtimeWeather = async (lat, lng) => {
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lng}&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,weather_code,wind_speed_10m&timezone=auto`;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 4000);
    const res = await fetch(url, { signal: controller.signal });
    clearTimeout(timeout);
    if (!res.ok) return null;
    const data = await res.json();
    return data.current;
  } catch (err) {
    console.warn('[Alerts Service] Weather fetch notice:', err.message);
    return null;
  }
};

/**
 * Resolves user's exact Area and City from coordinates via Nominatim / MapTiler.
 */
const reverseGeocodeLocality = async (lat, lng) => {
  // 1. Try Nominatim (OpenStreetMap) for high-accuracy Area and City
  try {
    const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&addressdetails=1`;
    const res = await fetch(url, {
      headers: { 'User-Agent': 'SafeTour-AI-Geofence-Service/2.0' },
      signal: AbortSignal.timeout(3500)
    });
    if (res.ok) {
      const data = await res.json();
      const addr = data.address || {};
      const area = addr.suburb || addr.neighbourhood || addr.village || addr.hamlet || addr.town || addr.city_district || addr.road || 'Local Area';
      const city = addr.city || addr.town || addr.county || addr.state_district || addr.state || 'District';
      return {
        area,
        city,
        formatted: `${area}, ${city}`
      };
    }
  } catch (_) {}

  // 2. Try MapTiler Geocoding fallback
  try {
    const apiKey = process.env.MAPTILER_API_KEY;
    if (apiKey) {
      const url = `https://api.maptiler.com/geocoding/${lng},${lat}.json?key=${apiKey}&limit=1`;
      const res = await fetch(url, { signal: AbortSignal.timeout(3000) });
      if (res.ok) {
        const data = await res.json();
        if (data.features && data.features.length > 0) {
          const feat = data.features[0];
          const parts = feat.place_name ? feat.place_name.split(',').map((s) => s.trim()) : [];
          const area = feat.text || parts[0] || 'Local Area';
          const city = parts.length >= 2 ? parts[parts.length - 2] : (parts[1] || 'District');
          return {
            area,
            city,
            formatted: `${area}, ${city}`
          };
        }
      }
    }
  } catch (_) {}

  // 3. Fallback based on Tamil Nadu / Srivilliputhur coordinates
  if (Math.abs(lat - 9.56) < 0.6 && Math.abs(lng - 77.67) < 0.6) {
    return { area: 'Krishnankoil', city: 'Srivilliputhur', formatted: 'Krishnankoil, Srivilliputhur' };
  }
  return { area: 'Local Sector', city: 'District', formatted: 'Local Sector, District' };
};

/**
 * Maps standard WMO weather codes and live metrics to actionable tourist safety advice.
 */
const interpretWeather = (weatherData) => {
  if (!weatherData) return null;
  const { weather_code, temperature_2m, apparent_temperature, relative_humidity_2m, wind_speed_10m, rain, precipitation } = weatherData;
  const temp = Math.round(temperature_2m);
  const feelsLike = Math.round(apparent_temperature);
  const humidity = Math.round(relative_humidity_2m);
  const wind = Math.round(wind_speed_10m);

  let condition = 'Fair Skies';
  let icon = '🌤️';
  let severity = 'info';
  let safetyTip = 'Favorable weather conditions for local travel and outdoor activities.';
  let isHazard = false;

  // Severe Thunderstorms
  if (weather_code === 95 || weather_code === 96 || weather_code === 99) {
    condition = 'Active Thunderstorm';
    icon = '⛈️';
    severity = 'critical';
    safetyTip = 'Lightning risk detected. Seek sturdy indoor shelter immediately. Avoid tall trees, open fields, and water bodies.';
    isHazard = true;
  } else if (weather_code === 65 || precipitation > 10.0 || rain > 10.0) {
    condition = 'Heavy Rain Surge';
    icon = '🌧️';
    severity = 'warning';
    safetyTip = 'Intense downpour in progress. Stay away from low-lying culverts, stream beds, and waterlogged paths.';
    isHazard = true;
  } else if ([51, 53, 55, 61, 63, 80, 81, 82].includes(weather_code) || rain > 0.2) {
    condition = 'Rain & Slippery Surfaces';
    icon = '🌦️';
    severity = 'warning';
    safetyTip = 'Precipitation observed. Pavements and footpaths may be slick. Carry rain gear and commute cautiously.';
    isHazard = true;
  } else if (weather_code === 45 || weather_code === 48) {
    condition = 'Dense Fog & Low Visibility';
    icon = '🌫️';
    severity = 'warning';
    safetyTip = 'Dense fog reducing road visibility. Use vehicle fog lights and reduce transit speed.';
    isHazard = true;
  } else if (feelsLike >= 38) {
    condition = 'High Heat Advisory';
    icon = '☀️';
    severity = 'warning';
    safetyTip = 'High heat index. Stay well hydrated, wear sun protection, and avoid prolonged midday sun exposure.';
    isHazard = true;
  } else if (wind >= 35) {
    condition = 'Gusty Winds Watch';
    icon = '💨';
    severity = 'warning';
    safetyTip = 'Strong wind gusts recorded. Beware of falling tree branches and unsecured signboards.';
    isHazard = true;
  } else if (weather_code === 3) {
    condition = 'Overcast Skies';
    icon = '☁️';
    safetyTip = 'Cloudy and temperate conditions across the area. Good conditions for daytime travel.';
  } else if (weather_code === 1 || weather_code === 2) {
    condition = 'Partly Cloudy';
    icon = '⛅';
    safetyTip = 'Pleasant weather in your immediate vicinity. Comfortable conditions for travel.';
  } else if (weather_code === 0) {
    condition = 'Clear Skies';
    icon = '☀️';
    safetyTip = 'Clear skies overhead. Carry water and sun protection when outdoors.';
  }

  return {
    condition,
    icon,
    severity,
    safetyTip,
    isHazard,
    temp,
    feelsLike,
    humidity,
    wind,
    rain: rain || precipitation || 0,
  };
};

/**
 * Dynamically synchronizes ONLY NECESSARY alerts strictly based on the user's PRESENT LOCATION:
 * 1. Live Weather Update / Advisory for current GPS coordinates.
 * 2. Real Geofence Danger Zone Breach / Approaching Alert (only if physically inside or <= 1.0 km).
 * 3. Automatically dismisses any distant (> 1.0 km) danger zones, obsolete mock alerts, or irrelevant advisories.
 *
 * @param {string|mongoose.Types.ObjectId} userId
 * @param {number} userLat
 * @param {number} userLng
 */
const syncRealtimeAlertsForLocation = async (userId, userLat, userLng) => {
  if (typeof userLat !== 'number' || typeof userLng !== 'number') return;

  const now = new Date();

  // 1. Purge all obsolete mock alerts, distant regional notes, or unrelated roadblocks
  await Alert.updateMany(
    {
      userId,
      status: 'active',
      $or: [
        { type: 'roadblock' },
        { message: /Entered Test Danger Zone/ },
        { title: /Regional Advisory/ },
      ],
    },
    { $set: { status: 'dismissed' } }
  );

  // 2. Evaluate ONLY immediate danger zones (physically inside or within 1.0 km)
  const activeZones = await DangerZone.find({ active: true });
  const zonesInside = await geofenceService.checkPointInZones(userLat, userLng);
  const insideZoneIds = new Set(zonesInside.map((z) => z._id.toString()));

  for (const zone of activeZones) {
    const zoneIdStr = zone._id.toString();
    const center = getZoneCenter(zone);
    if (!center) continue;

    const distKm = calculateHaversineDistanceKm(userLat, userLng, center.lat, center.lng);
    const isInside = insideZoneIds.has(zoneIdStr) || distKm < 0.25;

    if (isInside) {
      // Physical danger zone breach
      await Alert.findOneAndUpdate(
        { userId, zoneId: zone._id },
        {
          $set: {
            title: `⚡ Danger Zone Breach: Inside ${zone.name}`,
            type: 'geofence',
            severity: 'critical',
            locationName: zone.name,
            message: `Emergency Alert: You are currently inside the perimeter of ${zone.name}. ${zone.description || ''}`,
            safetyTip: 'Evacuate to designated safe perimeter immediately. Avoid edge zones or stream beds.',
            distanceKm: 0.0,
            coordinates: [center.lng, center.lat],
            status: 'active',
            createdAt: now,
          },
        },
        { upsert: true, new: true }
      );
    } else if (distKm <= 1.0) {
      // Approaching hazard within 1 km
      await Alert.findOneAndUpdate(
        { userId, zoneId: zone._id },
        {
          $set: {
            title: `⚠️ Approaching Hazard: ${zone.name} (${distKm.toFixed(1)} km)`,
            type: zone.category === 'wildlife' ? 'wildlife' : 'geofence',
            severity: zone.zoneType === 'red' ? 'warning' : 'advisory',
            locationName: zone.name,
            message: `Caution: High-risk zone situated ${distKm.toFixed(1)} km from your current position. ${zone.description || ''}`,
            safetyTip: 'Follow marked tourist paths and exercise heightened vigilance.',
            distanceKm: parseFloat(distKm.toFixed(1)),
            coordinates: [center.lng, center.lat],
            status: 'active',
            createdAt: now,
          },
        },
        { upsert: true, new: true }
      );
    } else {
      // Hazard is distant (> 1.0 km away). Dismiss any previous alert for this zone so user's feed stays clean
      await Alert.updateMany(
        { userId, zoneId: zone._id, status: 'active' },
        { $set: { status: 'dismissed' } }
      );
    }
  }

  // 3. Real-time Live Weather & Area Safety Updates for the user's exact Area and City
  const locality = await reverseGeocodeLocality(userLat, userLng);

  const weatherData = await fetchRealtimeWeather(userLat, userLng);
  if (weatherData) {
    const weather = interpretWeather(weatherData);
    if (weather) {
      const rainInfo = weather.rain > 0 ? ` Precipitation: ${weather.rain}mm.` : '';
      const weatherMsg = `Live weather at ${locality.area}, ${locality.city}: ${weather.condition}. Temperature is ${weather.temp}°C (feels like ${weather.feelsLike}°C) with ${weather.humidity}% humidity and ${weather.wind} km/h wind.${rainInfo}`;

      await Alert.findOneAndUpdate(
        { userId, type: 'weather' },
        {
          $set: {
            title: `${weather.icon} ${weather.isHazard ? 'Weather Alert' : 'Weather Update'}: ${locality.area}, ${locality.city} (${weather.temp}°C)`,
            type: 'weather',
            severity: weather.severity,
            locationName: locality.formatted,
            message: weatherMsg,
            safetyTip: `${weather.safetyTip} Advisory active across ${locality.city}.`,
            distanceKm: 0.0,
            coordinates: [userLng, userLat],
            status: 'active',
            createdAt: now,
          },
        },
        { upsert: true, new: true }
      );
    }
  }

  // 4. Area & City Tourist Safety Surveillance Alert
  await Alert.findOneAndUpdate(
    { userId, type: 'advisory' },
    {
      $set: {
        title: `🛡️ Tourist Safety Active: ${locality.area}, ${locality.city}`,
        type: 'advisory',
        severity: 'info',
        locationName: locality.formatted,
        message: `Active geofence surveillance and road safety monitoring active in ${locality.area}, ${locality.city}. Emergency response stations and medical services are mapped.`,
        safetyTip: `Emergency dial 112 (State Police) or trigger the in-app SOS button if in danger in ${locality.city}.`,
        distanceKm: 0.0,
        coordinates: [userLng, userLat],
        status: 'active',
        createdAt: now,
      },
    },
    { upsert: true, new: true }
  );
};

/**
 * Returns real-time alerts tailored strictly to the user's PRESENT LOCATION (Area and City).
 * Excludes distant hazards or obsolete mock alerts.
 *
 * @param {string|mongoose.Types.ObjectId} userId - The user's ID
 * @param {Object} options - { lat, lng, radiusKm, limit, skip, page }
 * @returns {Promise<Array>} List of real-time alerts
 */
const getUserAlerts = async (userId, options = {}) => {
  let userLat = options.lat !== undefined ? parseFloat(options.lat) : undefined;
  let userLng = options.lng !== undefined ? parseFloat(options.lng) : undefined;
  const radiusKm = parseFloat(options.radiusKm) || 5.0;

  // If coordinates not sent in request, pull the latest GPS ping from Location history
  if (userLat === undefined || userLng === undefined || isNaN(userLat) || isNaN(userLng)) {
    const latestPing = await Location.findOne({ userId }).sort({ timestamp: -1 });
    if (latestPing && typeof latestPing.lat === 'number' && typeof latestPing.lng === 'number') {
      userLat = latestPing.lat;
      userLng = latestPing.lng;
    }
  }

  // Graceful fallback coordinates if device GPS has not sent a ping yet (default Srivilliputhur/Krishnankoil area)
  userLat = (typeof userLat === 'number' && !isNaN(userLat)) ? userLat : 9.5680;
  userLng = (typeof userLng === 'number' && !isNaN(userLng)) ? userLng : 77.6740;

  // Synchronize real-time alerts strictly for coordinates
  await syncRealtimeAlertsForLocation(userId, userLat, userLng);

  const limit = Math.max(1, parseInt(options.limit, 10) || 50);
  const skip = options.skip !== undefined
    ? Math.max(0, parseInt(options.skip, 10))
    : options.page
      ? Math.max(0, (parseInt(options.page, 10) - 1) * limit)
      : 0;

  // Filter: ONLY active alerts relevant to user's location (live weather or distance <= radiusKm)
  const query = {
    userId,
    status: { $ne: 'dismissed' },
    $or: [
      { type: 'weather' },
      { distanceKm: { $lte: radiusKm } },
      { distanceKm: null },
    ],
  };

  const alerts = await Alert.find(query)
    .populate('zoneId', 'name zoneType category description')
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit);

  return alerts;
};

/**
 * Updates status from "active" to "acknowledged".
 */
const markAsRead = async (alertId, userId) => {
  const alert = await Alert.findOne({ _id: alertId, userId });
  if (!alert) {
    return null;
  }

  alert.status = 'acknowledged';
  alert.read = true;
  await alert.save();

  return alert;
};

/**
 * Returns count of active unread alerts for badge display, strictly matching the user's location.
 */
const getUnreadCount = async (userId, options = {}) => {
  let userLat = options.lat !== undefined ? parseFloat(options.lat) : undefined;
  let userLng = options.lng !== undefined ? parseFloat(options.lng) : undefined;
  const radiusKm = parseFloat(options.radiusKm) || 2.0;

  if (userLat === undefined || userLng === undefined || isNaN(userLat) || isNaN(userLng)) {
    const latestPing = await Location.findOne({ userId }).sort({ timestamp: -1 });
    if (latestPing && typeof latestPing.lat === 'number' && typeof latestPing.lng === 'number') {
      userLat = latestPing.lat;
      userLng = latestPing.lng;
    }
  }

  const query = {
    userId,
    status: 'active',
    read: false,
    $or: [
      { type: 'weather' },
      { distanceKm: { $lte: radiusKm } },
      { distanceKm: null },
    ],
  };

  const count = await Alert.countDocuments(query);
  return count;
};

module.exports = {
  getUserAlerts,
  markAsRead,
  getUnreadCount,
  syncRealtimeAlertsForLocation,
  fetchRealtimeWeather,
};
