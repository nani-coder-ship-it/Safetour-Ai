const chatService = require('./chat.service');

exports.processChat = async (req, res) => {
  try {
    const { message } = req.body;
    const userId = req.user?.uid || req.user?.email || req.user?.id || 'tourist';

    if (!message) {
      return res.status(400).json({
        success: false,
        message: 'Message is required'
      });
    }

    const reply = await chatService.processMessage(userId, message);

    res.status(200).json({
      success: true,
      data: {
        reply
      },
      message: 'Chat processed successfully'
    });
  } catch (error) {
    console.error('Chat Error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to process chat message',
      error: error.message
    });
  }
};
