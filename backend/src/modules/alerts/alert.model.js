const mongoose = require('mongoose');

const alertSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  type: {
    type: String,
    enum: ['geofence', 'roadblock', 'weather', 'sos'],
    required: true,
  },
  message: {
    type: String,
    required: true,
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
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// Index to quickly fetch a user's alerts ordered by time
alertSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Alert', alertSchema);
