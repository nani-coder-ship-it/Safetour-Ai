require('dotenv').config();
const mongoose = require('mongoose');
const DangerZone = require('./src/modules/geofence/geofence.model');

const seedTestZone = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('Connected to MongoDB');

    // Delete any existing test zones
    await DangerZone.deleteMany({ name: 'Test Danger Zone' });

    // The user's Fake GPS location is Lat: 14.4266, Lng: 79.9566
    // We will create a small box around this coordinate (GeoJSON format: [Lng, Lat])
    const newZone = await DangerZone.create({
      name: 'Test Danger Zone',
      zoneType: 'red',
      polygon: {
        type: 'Polygon',
        coordinates: [
          [
            [79.9500, 14.4200], // Bottom Left
            [79.9600, 14.4200], // Bottom Right
            [79.9600, 14.4300], // Top Right
            [79.9500, 14.4300], // Top Left
            [79.9500, 14.4200], // Bottom Left (Close the polygon)
          ]
        ],
      },
      source: 'manual',
    });

    console.log('Successfully created test danger zone:', newZone.name);
    process.exit(0);
  } catch (error) {
    console.error('Error seeding test zone:', error);
    process.exit(1);
  }
};

seedTestZone();
