require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const connectDB = require('./src/config/db');
const authRoutes = require('./src/modules/auth/auth.routes');
const locationRoutes = require('./src/modules/location/location.routes');
const geofenceRoutes = require('./src/modules/geofence/geofence.routes');
const chatRoutes = require('./src/modules/chat/chat.routes');
const poiRoutes = require('./src/modules/poi/poi.routes');
const errorHandler = require('./src/middleware/error.middleware');

// Initialize database connection
connectDB();

const app = express();

// Middlewares
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

if (process.env.NODE_ENV !== 'production') {
  app.use(morgan('dev'));
}

// Default route
app.get('/', (req, res) => {
  res.status(200).json({ success: true, message: 'SafeTour AI Backend API is running' });
});

// Mount routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/location', locationRoutes);
app.use('/api/v1/geofence', geofenceRoutes);
app.use('/api/v1/chat', chatRoutes);
app.use('/api/v1/poi', poiRoutes);

// Error Handler Middleware (must be applied after routes)
app.use(errorHandler);

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
