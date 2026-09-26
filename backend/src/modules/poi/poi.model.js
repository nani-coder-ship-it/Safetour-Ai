const mongoose = require('mongoose');

const poiSchema = new mongoose.Schema({
  osmId: {
    type: String,
    required: true,
    unique: true,
    trim: true,
  },
  name: {
    type: String,
    default: 'Unnamed POI',
    trim: true,
  },
  type: {
    type: String,
    enum: [
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
    ],
    required: true,
  },
  subType: {
    type: String,
    default: null,
    trim: true,
  },
  address: {
    type: String,
    default: null,
    trim: true,
  },
  phone: {
    type: String,
    default: null,
    trim: true,
  },
  website: {
    type: String,
    default: null,
    trim: true,
  },
  lat: {
    type: Number,
    required: true,
  },
  lng: {
    type: Number,
    required: true,
  },
  location: {
    type: {
      type: String,
      enum: ['Point'],
      required: true,
      default: 'Point',
    },
    coordinates: {
      type: [Number], // [longitude, latitude] - strictly [lng, lat] for GeoJSON
      required: true,
    },
  },
  rating: {
    type: Number,
    default: null,
  },
  lastSynced: {
    type: Date,
    default: Date.now,
  },
});

// 2dsphere index on location for geospatial proximity queries ($near, $geoWithin)
poiSchema.index({ location: '2dsphere' });

// Compound index for fast queries filtering by type and checking cache freshness
poiSchema.index({ type: 1, lastSynced: -1 });
poiSchema.index({ type: 1, subType: 1 });

module.exports = mongoose.model('POI', poiSchema);
