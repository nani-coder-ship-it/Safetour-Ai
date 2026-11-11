/**
 * Natural Hazard & Danger Zones Database Seeder for SafeTour AI
 * Pre-populates MongoDB with geographical hazard polygons for:
 * - Mountain Peaks & Steep Cliffs (fall hazards, landslides)
 * - Deep Rivers & Waterfalls (flash floods, whirlpools, slippery rocks)
 * - Lakes & Deep Reservoirs (drowning, strong suction currents)
 * - Wildlife & Elephant Corridors (animal conflict risk)
 * - Local Krishnankoil / Srivilliputtur testing hazard zone
 */

require('dotenv').config();
const mongoose = require('mongoose');
const DangerZone = require('./src/modules/geofence/geofence.model');

const NATURAL_HAZARDS = [
  // =========================================================================
  // 1. LOCAL KRISHNANKOIL / SRIVILLIPUTTUR TESTING HAZARD ZONES
  //    (Immediately testable at or near lat=9.5714, lng=77.6756)
  // =========================================================================
  {
    name: 'Naranapuram Lake (Kanmoi) Deep Water Hazard',
    zoneType: 'red',
    category: 'lake',
    description: 'Deep irrigation reservoir with hidden sinkholes and soft silt mud. Swimming and water entry strictly prohibited.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [77.6950, 9.5850],
          [77.7150, 9.5850],
          [77.7150, 9.6050],
          [77.6950, 9.6050],
          [77.6950, 9.5850],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Pilavakkal Dam Deep Reservoir & Spillway',
    zoneType: 'red',
    category: 'reservoir',
    description: 'Deep dam reservoir with intense water suction currents near sluice gates. Sudden depth drop exceeds 18 meters.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [77.5800, 9.6100],
          [77.6050, 9.6100],
          [77.6050, 9.6350],
          [77.5800, 9.6350],
          [77.5800, 9.6100],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Ayyanar Falls Flash Flood & Slippery Boulders',
    zoneType: 'red',
    category: 'waterfall',
    description: 'Severe flash flood danger during sudden rains in upper Western Ghats. Extreme fall hazard on mossy rocks.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [77.5350, 9.5250],
          [77.5600, 9.5250],
          [77.5600, 9.5450],
          [77.5350, 9.5450],
          [77.5350, 9.5250],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Shenbagathoppu Forest Elephant & Wildlife Corridor',
    zoneType: 'red',
    category: 'wildlife',
    description: 'Dense sanctuary buffer zone with active wild elephant herds and sloth bears. Walking alone without forest rangers is prohibited.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [77.5500, 9.4950],
          [77.5900, 9.4950],
          [77.5900, 9.5250],
          [77.5500, 9.5250],
          [77.5500, 9.4950],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Sanjeevi Hills Steep Cliff Edge & Drop-Off',
    zoneType: 'yellow',
    category: 'cliff',
    description: 'Steep 250m rocky cliff edge with crumbling loose gravel. Maintain at least 15 meters safe distance from perimeter.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [77.6080, 9.5050],
          [77.6250, 9.5050],
          [77.6250, 9.5200],
          [77.6080, 9.5200],
          [77.6080, 9.5050],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },

  // =========================================================================
  // 2. WESTERN GHATS & POPULAR TAMIL NADU TOURIST HAZARDS
  // =========================================================================
  {
    name: 'Kodaikanal Suicide Point (Green Valley View) 5000ft Sheer Cliff',
    zoneType: 'red',
    category: 'cliff',
    description: 'Extremely deep vertical drop of 5,000 feet into the Vaigai valley. Dense fog causes severe disorientation.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [77.4820, 10.2080],
          [77.4980, 10.2080],
          [77.4980, 10.2200],
          [77.4820, 10.2200],
          [77.4820, 10.2080],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Courtallam Main & Old Falls Torrential Gorge',
    zoneType: 'red',
    category: 'waterfall',
    description: 'Violent water torrent surges without advance notice during Western Ghats monsoon downpours.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [77.2650, 8.9250],
          [77.2800, 8.9250],
          [77.2800, 8.9400],
          [77.2650, 8.9400],
          [77.2650, 8.9250],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Hogenakkal Falls Granite River Whirlpools',
    zoneType: 'red',
    category: 'river',
    description: 'Lethal underwater whirlpools and turbulent river currents within narrow granite canyon chasms.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [77.7650, 12.1100],
          [77.7850, 12.1100],
          [77.7850, 12.1280],
          [77.7650, 12.1280],
          [77.7650, 12.1100],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Meghamalai Highwavys Mountain Landslide & Mist Corridor',
    zoneType: 'yellow',
    category: 'landslide',
    description: 'Active landslide-prone hairpin ghat road. Zero-visibility mist and elephant crossings past sunset.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [77.3950, 9.6900],
          [77.4350, 9.6900],
          [77.4350, 9.7300],
          [77.3950, 9.7300],
          [77.3950, 9.6900],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Pykara Falls & Deep Lake Zone (Ooty / Nilgiris)',
    zoneType: 'red',
    category: 'lake',
    description: 'Near-freezing deep water causing rapid hypothermia and hidden underwater tree branches.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [76.5900, 11.4850],
          [76.6200, 11.4850],
          [76.6200, 11.5150],
          [76.5900, 11.5150],
          [76.5900, 11.4850],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },

  // =========================================================================
  // 3. MAJOR NATIONAL TOURIST NATURAL HAZARDS (INDIA-WIDE)
  // =========================================================================
  {
    name: 'Rishikesh Shivpuri White Water Rapids & Ganga Whirlpools',
    zoneType: 'red',
    category: 'river',
    description: 'Violent Class IV/V river rapids, freezing Himalayan meltwater, and deep river vortexes.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [78.3750, 30.1200],
          [78.4050, 30.1200],
          [78.4050, 30.1500],
          [78.3750, 30.1500],
          [78.3750, 30.1200],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Goa Baga / Calangute Monsoon Rip Current Hazard',
    zoneType: 'red',
    category: 'lake',
    description: 'High surf rip currents pulling swimmers outward into deep sea. Swimming banned during red flag warning.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [73.7400, 15.5350],
          [73.7600, 15.5350],
          [73.7600, 15.5650],
          [73.7400, 15.5650],
          [73.7400, 15.5350],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Rohtang Pass Avalanche & Extreme High-Altitude Ridge',
    zoneType: 'red',
    category: 'mountain_peak',
    description: 'Elevation 13,058 ft. Frequent blizzard whiteouts, sudden oxygen drops, and falling rock/avalanche zones.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [77.2250, 32.3600],
          [77.2550, 32.3600],
          [77.2550, 32.3900],
          [77.2250, 32.3900],
          [77.2250, 32.3600],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
  {
    name: 'Dudhsagar Falls Dangerous Railway Track & Torrent Pool',
    zoneType: 'red',
    category: 'waterfall',
    description: 'Active railway tracks with fast-moving freight trains and turbulent waterfall base pool drowning risk.',
    polygon: {
      type: 'Polygon',
      coordinates: [
        [
          [74.3050, 15.3050],
          [74.3250, 15.3050],
          [74.3250, 15.3250],
          [74.3050, 15.3250],
          [74.3050, 15.3050],
        ],
      ],
    },
    source: 'natural-hazard-seed',
  },
];

async function seedHazards() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB. Seeding natural hazard danger zones...');

    let inserted = 0;
    let updated = 0;

    for (const hazard of NATURAL_HAZARDS) {
      const existing = await DangerZone.findOne({ name: hazard.name });
      if (existing) {
        existing.zoneType = hazard.zoneType;
        existing.category = hazard.category;
        existing.description = hazard.description;
        existing.polygon = hazard.polygon;
        existing.active = true;
        existing.source = 'natural-hazard-seed';
        await existing.save();
        updated++;
      } else {
        await DangerZone.create({
          ...hazard,
          active: true,
        });
        inserted++;
      }
    }

    console.log(`\n========================================================`);
    console.log(`✅ Natural Hazards Seeding Complete!`);
    console.log(`   - New Hazard Zones Created: ${inserted}`);
    console.log(`   - Existing Hazard Zones Updated: ${updated}`);
    console.log(`   - Total Active Danger Zones in DB: ${await DangerZone.countDocuments({ active: true })}`);
    console.log(`========================================================\n`);

    process.exit(0);
  } catch (error) {
    console.error('Error seeding natural hazard zones:', error);
    process.exit(1);
  }
}

seedHazards();
