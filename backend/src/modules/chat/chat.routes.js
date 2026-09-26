const express = require('express');
const router = express.Router();
const chatController = require('./chat.controller');
const { protect } = require('../../middleware/auth.middleware');

router.post('/', protect, chatController.processChat);

module.exports = router;
