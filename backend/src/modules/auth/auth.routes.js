const express = require('express');
const { register, getMe } = require('./auth.controller');
const { protect } = require('../../middleware/auth.middleware');

const router = express.Router();

router.post('/register', register);
router.get('/me', protect, getMe);

module.exports = router;
