const User = require('./auth.model');

/**
 * Validates phone format: optional leading +, 10 to 15 digits (spaces and dashes permitted in raw string)
 */
const isValidPhoneNumber = (phone) => {
  if (!phone || typeof phone !== 'string') return false;
  const cleanPhone = phone.replace(/[\s\-()]/g, '');
  return /^\+?[0-9]{10,15}$/.test(cleanPhone);
};

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
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }
  return user;
};

/**
 * Updates user profile fields safely without wiping unspecified fields.
 * Validates emergency contacts: non-empty name, 10-15 digit phone, max 5 contacts.
 *
 * @param {string} firebaseUid
 * @param {Object} updateData - { name, phone, emergencyContacts }
 */
const updateUserProfile = async (firebaseUid, updateData = {}) => {
  const updateFields = {};

  // Partial update for name
  if (updateData.name !== undefined) {
    if (typeof updateData.name !== 'string' || !updateData.name.trim()) {
      const error = new Error('Name cannot be empty');
      error.statusCode = 400;
      throw error;
    }
    updateFields.name = updateData.name.trim();
  }

  // Partial update for user personal phone
  if (updateData.phone !== undefined) {
    if (updateData.phone !== null && updateData.phone !== '') {
      if (!isValidPhoneNumber(updateData.phone)) {
        const error = new Error('Invalid user phone number. Must be 10-15 digits with optional leading +');
        error.statusCode = 400;
        throw error;
      }
      updateFields.phone = updateData.phone.trim();
    } else {
      updateFields.phone = '';
    }
  }

  // Partial update for emergencyContacts
  if (updateData.emergencyContacts !== undefined) {
    if (!Array.isArray(updateData.emergencyContacts)) {
      const error = new Error('Emergency contacts must be an array');
      error.statusCode = 400;
      throw error;
    }

    if (updateData.emergencyContacts.length > 5) {
      const error = new Error('Maximum of 5 emergency contacts allowed');
      error.statusCode = 400;
      throw error;
    }

    const validatedContacts = [];

    for (let i = 0; i < updateData.emergencyContacts.length; i++) {
      const contact = updateData.emergencyContacts[i];

      if (!contact || typeof contact !== 'object') {
        const error = new Error(`Contact at index ${i} is invalid`);
        error.statusCode = 400;
        throw error;
      }

      // Name validation: non-empty string
      if (!contact.name || typeof contact.name !== 'string' || !contact.name.trim()) {
        const error = new Error(`Contact #${i + 1} must have a non-empty name`);
        error.statusCode = 400;
        throw error;
      }

      // Phone validation: 10-15 digits with optional leading +
      if (!contact.phone || !isValidPhoneNumber(contact.phone)) {
        const error = new Error(
          `Contact "${contact.name.trim()}" has an invalid phone number. Must be 10-15 digits with optional leading +`
        );
        error.statusCode = 400;
        throw error;
      }

      validatedContacts.push({
        name: contact.name.trim(),
        phone: contact.phone.toString().trim(),
        relation: (contact.relation && typeof contact.relation === 'string') ? contact.relation.trim() : '',
      });
    }

    updateFields.emergencyContacts = validatedContacts;
  }

  const updatedUser = await User.findOneAndUpdate(
    { firebaseUid },
    { $set: updateFields },
    { new: true, runValidators: true }
  );

  if (!updatedUser) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  return updatedUser;
};

module.exports = {
  createUserProfile,
  getUserByFirebaseUid,
  updateUserProfile,
  isValidPhoneNumber,
};
