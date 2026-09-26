const admin = require('firebase-admin');

// Format the private key to handle both actual newlines or escaped \n characters
const privateKey = process.env.FIREBASE_ADMIN_PRIVATE_KEY 
  ? process.env.FIREBASE_ADMIN_PRIVATE_KEY.replace(/\\n/g, '\n')
  : undefined;

admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_ADMIN_PROJECT_ID,
    clientEmail: process.env.FIREBASE_ADMIN_CLIENT_EMAIL,
    privateKey: privateKey,
  }),
});

module.exports = admin;
