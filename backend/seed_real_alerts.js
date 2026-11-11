require('dotenv').config();
const mongoose = require('mongoose');
const Alert = require('./src/modules/alerts/alert.model');
const User = require('./src/modules/auth/auth.model');
const DangerZone = require('./src/modules/geofence/geofence.model');

async function seedRealAlerts() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to MongoDB. Seeding realistic tourist safety alerts...');

  // Find users
  const users = await User.find();
  if (users.length === 0) {
    console.log('No users found in database.');
    process.exit(0);
  }

  // Clear obsolete mock alerts
  await Alert.deleteMany({ message: 'Entered Test Danger Zone' });

  // Find any danger zones for reference
  const ayyanarZone = await DangerZone.findOne({ name: /Ayyanar/i });
  const wildlifeZone = await DangerZone.findOne({ name: /Shenbagathoppu/i });

  const now = Date.now();

  for (const user of users) {
    // Delete any old alerts for this user to start fresh with real ones
    await Alert.deleteMany({ userId: user._id });

    const authenticAlerts = [
      {
        userId: user._id,
        title: 'Flash Flood Warning: Ayyanar Falls',
        type: 'geofence',
        severity: 'critical',
        locationName: 'Ayyanar Falls & Upper Streams',
        message: 'High water surge detected upstream. Stream beds at immediate risk.',
        safetyTip: 'Evacuate stream areas immediately. Stay on high ground.',
        zoneId: ayyanarZone ? ayyanarZone._id : null,
        status: 'active',
        read: false,
        createdAt: new Date(now - 25 * 60 * 1000), // 25 mins ago
      },
      {
        userId: user._id,
        title: 'Wildlife Advisory: Elephant Herd',
        type: 'wildlife',
        severity: 'warning',
        locationName: 'Shenbagathoppu Forest Border',
        message: 'Wild elephant herd crossing pathways near fringe fields.',
        safetyTip: 'Remain in vehicles. Avoid evening walks near sanctuary border.',
        zoneId: wildlifeZone ? wildlifeZone._id : null,
        status: 'active',
        read: false,
        createdAt: new Date(now - 2 * 60 * 60 * 1000), // 2 hrs ago
      },
      {
        userId: user._id,
        title: 'Thunderstorm & Lightning Watch',
        type: 'weather',
        severity: 'warning',
        locationName: 'Krishnankoil District',
        message: 'Severe lightning & 45 km/h wind gusts moving across region.',
        safetyTip: 'Avoid open grounds and trees. Seek sturdy shelter.',
        status: 'active',
        read: false,
        createdAt: new Date(now - 4 * 60 * 60 * 1000), // 4 hrs ago
      },
      {
        userId: user._id,
        title: 'NH-744 Single Lane Traffic',
        type: 'roadblock',
        severity: 'advisory',
        locationName: 'NH-744 (Koomapatti Junction)',
        message: 'Asphalt & culvert repairs in progress with single-lane flow.',
        safetyTip: 'Slow down under 40 km/h and follow detour markers.',
        status: 'acknowledged',
        read: true,
        createdAt: new Date(now - 8 * 60 * 60 * 1000), // 8 hrs ago
      },
      {
        userId: user._id,
        title: 'Safe Tourist Perimeter Active',
        type: 'advisory',
        severity: 'info',
        locationName: 'Kalasalingam Campus Zone',
        message: 'Verified safe perimeter with active 24/7 security patrol.',
        safetyTip: 'Keep GPS enabled for continuous geofence surveillance.',
        status: 'acknowledged',
        read: true,
        createdAt: new Date(now - 14 * 60 * 60 * 1000), // 14 hrs ago
      },
    ];

    await Alert.insertMany(authenticAlerts);
    console.log(`Seeded ${authenticAlerts.length} realistic alerts for user ${user.name} (${user.email})`);
  }

  console.log('Alert seeding complete!');
  process.exit(0);
}

seedRealAlerts().catch(err => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
