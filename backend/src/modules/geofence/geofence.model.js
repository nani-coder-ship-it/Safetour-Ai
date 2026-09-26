const mongoose = require('mongoose');

const dangerZoneSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  zoneType: {
    type: String,
    enum: ['red', 'yellow', 'green', 'blue'],
    required: true,
  },
  polygon: {
    type: {
      type: String,
      enum: ['Polygon'],
      required: true,
      default: 'Polygon',
    },
    // GeoJSON Polygon coordinates are an array of arrays of arrays: [[[lng, lat], ...]]
    coordinates: {
      type: [[[Number]]], 
      required: true,
    },
  },
  source: {
    type: String,
    enum: ['manual', 'ai-detected'],
    default: 'manual',
  },
  active: {
    type: Boolean,
    default: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// Add 2dsphere index for fast geospatial intersection queries
dangerZoneSchema.index({ polygon: '2dsphere' });

module.exports = mongoose.model('DangerZone', dangerZoneSchema);
