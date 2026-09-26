const User = require('./auth.model');

const createUserProfile = async (userData) => {
  // Check if user already exists
  const existingUser = await User.findOne({ firebaseUid: userData.firebaseUid });
  if (existingUser) {
    throw new Error('User already exists in the database');
  }

  const user = await User.create(userData);
  return user;
};

const getUserByFirebaseUid = async (uid) => {
  const user = await User.findOne({ firebaseUid: uid });
  if (!user) {
    throw new Error('User not found');
  }
  return user;
};

module.exports = {
  createUserProfile,
  getUserByFirebaseUid,
};
