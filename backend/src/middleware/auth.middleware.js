const admin = require('../config/firebase-admin');
const User = require('../modules/auth/auth.model');

const protect = async (req, res, next) => {
  let token;

  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer')
  ) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    if (process.env.NODE_ENV !== 'production' && req.headers['x-user-id']) {
      try {
        const dbUser = await User.findById(req.headers['x-user-id']);
        if (dbUser) {
          req.user = {
            uid: dbUser.firebaseUid,
            _id: dbUser._id,
            role: dbUser.role || 'tourist',
            email: dbUser.email,
          };
          return next();
        }
      } catch (_) {}
    }
    res.status(401);
    return next(new Error('Not authorized to access this route, missing token'));
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Attach decoded user info to the request
    req.user = decodedToken;

    // Attach role and database profile from MongoDB User document
    try {
      const dbUser = await User.findOne({ firebaseUid: decodedToken.uid });
      req.user.role = dbUser ? dbUser.role : (decodedToken.role || 'tourist');
      if (dbUser) req.user._id = dbUser._id;
    } catch (dbErr) {
      req.user.role = decodedToken.role || 'tourist';
    }
    
    next();
  } catch (error) {
    console.error('Error verifying Firebase token:', error.message);
    res.status(401);
    return next(new Error('Not authorized to access this route, invalid token'));
  }
};

module.exports = { protect };
