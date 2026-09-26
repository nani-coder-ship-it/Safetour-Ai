const authService = require('./auth.service');

const register = async (req, res, next) => {
  try {
    // The Flutter app sends { uid, email, name }
    const { uid, firebaseUid, email, name } = req.body;
    
    const targetUid = uid || firebaseUid;

    if (!targetUid || !email || !name) {
      res.status(400);
      throw new Error('Please provide all required fields (uid, email, name)');
    }

    const userData = {
      firebaseUid: targetUid,
      email,
      name,
    };

    const user = await authService.createUserProfile(userData);

    res.status(201).json({
      success: true,
      data: user,
      message: 'User profile created successfully',
    });
  } catch (error) {
    next(error);
  }
};

const getMe = async (req, res, next) => {
  try {
    // req.user is populated by the auth.middleware (Firebase token decoded)
    const firebaseUid = req.user.uid;
    
    const user = await authService.getUserByFirebaseUid(firebaseUid);

    res.status(200).json({
      success: true,
      data: user,
      message: 'User profile retrieved successfully',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  getMe,
};
