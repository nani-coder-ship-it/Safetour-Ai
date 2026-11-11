const mongoose = require('mongoose');

const authSchema = new mongoose.Schema({
  firebaseUid: {
    type: String,
    required: true,
    unique: true,
  },
  email: {
    type: String,
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  phone: {
    type: String,
    trim: true,
  },
  emergencyContacts: [
    {
      name: {
        type: String,
        required: true,
        trim: true,
      },
      phone: {
        type: String,
        required: true,
        trim: true,
      },
      relation: {
        type: String,
        trim: true,
        default: '',
      },
    },
  ],
  role: {
    type: String,
    default: 'tourist',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('User', authSchema);
