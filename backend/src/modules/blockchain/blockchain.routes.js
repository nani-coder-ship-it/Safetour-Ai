const express = require('express');
const {
  getMyDigitalId,
  updateMyDigitalId,
  verifyDigitalId,
} = require('./blockchain.controller');
const { protect } = require('../../middleware/auth.middleware');

const router = express.Router();

// Public verification route
router.get('/verify/:identifier', verifyDigitalId);

// Protected routes requiring authentication
router.use(protect);
router.get('/id', getMyDigitalId);
router.put('/id', updateMyDigitalId);

module.exports = router;
