const admin = require('../config/firebase-admin');

const protect = async (req, res, next) => {
  let token;

  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer')
  ) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    res.status(401);
    return next(new Error('Not authorized to access this route, missing token'));
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Attach decoded user info to the request
    req.user = decodedToken;
    
    next();
  } catch (error) {
    console.error('Error verifying Firebase token:', error.message);
    res.status(401);
    return next(new Error('Not authorized to access this route, invalid token'));
  }
};

module.exports = { protect };
