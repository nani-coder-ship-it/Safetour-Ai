require('dotenv').config();
const mongoose = require('mongoose');
const { getNearby } = require('./src/modules/poi/poi.service');

// Kalasalingam University / Krishnankoil coordinates
const userLat = 9.5713869;
const userLng = 77.6755805;

async function runStep5Tests() {
  console.log('Connecting to MongoDB...');
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to MongoDB.\n');

  const radii = [1000, 3000, 5000, 8000];

  console.log('================================================================');
  console.log(' STEP 5 VERIFICATION: HOTELS & LODGES NEAR KRISHNANKOIL');
  console.log(` Location: Krishnankoil (lat: ${userLat}, lng: ${userLng})`);
  console.log('================================================================\n');

  for (const radius of radii) {
    console.log(`\n>>> TESTING RADIUS: ${radius}m (${radius / 1000}km) <<<`);
    try {
      const results = await getNearby(userLat, userLng, radius, 'hotel');
      console.log(`\nResult for ${radius / 1000}km: ${results.length} place(s) returned.`);
      if (results.length === 0) {
        console.log(`  [HONEST EMPTY STATE] No commercial hotels/lodges found within ${radius / 1000}km.`);
      } else {
        results.forEach((p, idx) => {
          console.log(`  ${idx + 1}. "${p.name}" | SubType: [${p.subType}] | Distance: ${p.distance}m | Lat: ${p.lat}, Lng: ${p.lng}`);
        });
      }
    } catch (err) {
      console.error(`Error querying ${radius}m:`, err.message);
    }
  }

  // Cross-category check: Ensure Nelson Mandela Mens Hostel is NOT in tourist_spot
  console.log('\n\n================================================================');
  console.log(' VERIFYING STUDENT HOSTEL EXCLUSION ACROSS CATEGORIES');
  console.log(' Testing category: "tourist_spot" at 3km');
  console.log('================================================================\n');
  try {
    const touristSpots = await getNearby(userLat, userLng, 3000, 'tourist_spot');
    console.log(`Result for tourist_spot at 3km: ${touristSpots.length} place(s).`);
    const studentHostelFound = touristSpots.find(p => /nelson mandela|hostel/i.test(p.name));
    if (studentHostelFound) {
      console.error(`  FAIL: Found student hostel in tourist spots: "${studentHostelFound.name}"`);
    } else {
      console.log('  PASS: No student hostels found in tourist spots!');
      touristSpots.slice(0, 5).forEach((p, idx) => {
        console.log(`  ${idx + 1}. "${p.name}" | SubType: [${p.subType}] | Distance: ${p.distance}m`);
      });
    }
  } catch (err) {
    console.error('Error querying tourist spots:', err.message);
  }

  process.exit(0);
}

runStep5Tests().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
