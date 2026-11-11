require('dotenv').config();
const mongoose = require('mongoose');
const DigitalId = require('./src/modules/blockchain/digital_id.model');
const { verifyCredential } = require('./src/modules/blockchain/blockchain.service');

async function test() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('MongoDB Connected');

    const allIds = await DigitalId.find({});
    console.log(`Found ${allIds.length} Digital ID records in MongoDB:`);
    for (const d of allIds) {
      console.log(`- ID: ${d._id}, TouristId: ${d.touristIdNumber}, qrPayload: ${d.qrPayload}`);
    }

    if (allIds.length > 0) {
      const sample = allIds[0];
      const verified = await verifyCredential(sample.touristIdNumber);
      console.log('\nVerification test result for', sample.touristIdNumber, ':', verified.verified, verified.fullName, verified.status);
    }
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

test();
