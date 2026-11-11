const express = require('express');
const { register, getMe, updateMe } = require('./auth.controller');
const { protect } = require('../../middleware/auth.middleware');

const router = express.Router();

router.post('/register', register);
router.get('/me', protect, getMe);
router.put('/me', protect, updateMe);

module.exports = router;
