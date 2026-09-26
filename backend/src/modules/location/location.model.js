const mongoose = require('mongoose');

const locationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  // We keep lat/lng at the top level for easy access if needed
  lat: {
    type: Number,
    required: true,
  },
  lng: {
    type: Number,
    required: true,
  },
  // GeoJSON object for MongoDB 2dsphere geospatial queries
  location: {
    type: {
      type: String,
      enum: ['Point'],
      required: true,
      default: 'Point',
    },
    coordinates: {
      type: [Number], // [longitude, latitude] - Order is strictly lng, lat in GeoJSON
      required: true,
    },
  },
  speed: {
    type: Number, // Speed in km/h or m/s depending on the app logic
    default: null,
  },
  battery: {
    type: Number, // Battery percentage
    default: null,
  },
  network: {
    type: String, // WiFi, 4G, 5G, etc.
    default: null,
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
});

// Create a 2dsphere index on the 'location' GeoJSON field for proximity/geofencing queries
locationSchema.index({ location: '2dsphere' });
// Index on userId for fast historical lookups
locationSchema.index({ userId: 1, timestamp: -1 });

module.exports = mongoose.model('Location', locationSchema);
