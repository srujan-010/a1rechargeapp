const { initializeApp, cert } = require('firebase-admin/app');
const path = require('path');
const fs = require('fs');

let app;

const initFirebaseAdmin = () => {
  try {
    const serviceAccountPath = path.join(__dirname, '..', 'service-account.json');
    
    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = require(serviceAccountPath);
      app = initializeApp({
        credential: cert(serviceAccount)
      });
      console.log('Firebase Admin SDK initialized using service-account.json');
    } else {
      // Fallback to Application Default Credentials
      app = initializeApp();
      console.log('Firebase Admin SDK initialized using Application Default Credentials (missing service-account.json)');
    }
  } catch (error) {
    console.error('Firebase Admin SDK Initialization Error:', error.message);
  }
};

const getApp = () => app;

module.exports = { getApp, initFirebaseAdmin };
