require('dotenv').config();
const mongoose = require('mongoose');
const { getNearby } = require('./src/modules/poi/poi.service');

const userLat = 9.5713869;
const userLng = 77.6755805;

async function test() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to MongoDB. Testing getNearby...');

  // 1. Test Hotel at 3km (should exclude student hostels and fallback or show valid lodges)
  console.log('\n--- TEST 1: Hotel at 3km ---');
  const hotels3km = await getNearby(userLat, userLng, 3000, 'hotel');
  console.log(`Found ${hotels3km.length} hotels at 3km:`);
  hotels3km.forEach((p, i) => console.log(`  ${i + 1}. "${p.name}" (${p.distance}m) [${p.subType}]`));

  // 2. Test Hotel at 8km
  console.log('\n--- TEST 2: Hotel at 8km ---');
  const hotels8km = await getNearby(userLat, userLng, 8000, 'hotel');
  console.log(`Found ${hotels8km.length} hotels at 8km:`);
  hotels8km.forEach((p, i) => console.log(`  ${i + 1}. "${p.name}" (${p.distance}m) [${p.subType}]`));

  // 3. Test Tourist Spots at 3km
  console.log('\n--- TEST 3: Tourist Spot at 3km ---');
  const spots3km = await getNearby(userLat, userLng, 3000, 'tourist_spot');
  console.log(`Found ${spots3km.length} tourist spots at 3km:`);
  spots3km.forEach((p, i) => console.log(`  ${i + 1}. "${p.name}" (${p.distance}m) [${p.subType}]`));

  // 4. Test Restaurants at 3km
  console.log('\n--- TEST 4: Restaurant at 3km ---');
  const food3km = await getNearby(userLat, userLng, 3000, 'restaurant');
  console.log(`Found ${food3km.length} restaurants at 3km:`);
  food3km.forEach((p, i) => console.log(`  ${i + 1}. "${p.name}" (${p.distance}m) [${p.subType}]`));

  process.exit(0);
}

test().catch(err => {
  console.error('Test failed:', err);
  process.exit(1);
});
