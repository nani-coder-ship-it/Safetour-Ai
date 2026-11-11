const mongoose = require('mongoose');

let isConnecting = false;

const connectDB = async () => {
  if (isConnecting) return;
  isConnecting = true;

  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      serverSelectionTimeoutMS: 5000,
    });
    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
    isConnecting = false;
  } catch (error) {
    isConnecting = false;
    console.error(`\n⚠️  [MongoDB Atlas Connection Notice]`);
    console.error(`Error: ${error.message}`);
    console.error(`👉 Common fix: Your current IP is not whitelisted in MongoDB Atlas.`);
    console.error(`👉 Log into https://cloud.mongodb.com -> Network Access -> Add IP Address -> Allow Access From Anywhere (0.0.0.0/0).`);
    console.error(`🔄 Will automatically retry connecting in 8 seconds...\n`);

    // Do NOT exit process. Keep Express server running so API routes and POI providers stay operational.
    setTimeout(connectDB, 8000);
  }
};

mongoose.connection.on('disconnected', () => {
  console.warn('⚠️  MongoDB connection lost. Reconnecting...');
  setTimeout(connectDB, 5000);
});

module.exports = connectDB;
