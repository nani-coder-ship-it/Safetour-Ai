const mongoose = require('mongoose');

const alertSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  title: {
    type: String,
    default: 'Safety Alert',
  },
  type: {
    type: String,
    enum: ['geofence', 'roadblock', 'weather', 'wildlife', 'sos', 'advisory'],
    required: true,
  },
  severity: {
    type: String,
    enum: ['critical', 'warning', 'advisory', 'info'],
    default: 'warning',
  },
  locationName: {
    type: String,
    default: null,
  },
  message: {
    type: String,
    required: true,
  },
  safetyTip: {
    type: String,
    default: null,
  },
  zoneId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'DangerZone',
    default: null,
  },
  read: {
    type: Boolean,
    default: false,
  },
  status: {
    type: String,
    enum: ['active', 'acknowledged', 'dismissed'],
    default: 'active',
  },
  distanceKm: {
    type: Number,
    default: null,
  },
  coordinates: {
    type: [Number], // [lng, lat]
    default: null,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// Index to quickly fetch a user's alerts ordered by time
alertSchema.index({ userId: 1, createdAt: -1 });
alertSchema.index({ userId: 1, zoneId: 1, status: 1 });

module.exports = mongoose.model('Alert', alertSchema);
