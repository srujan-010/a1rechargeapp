const { initializeApp, cert } = require('firebase-admin/app');
const path = require('path');
const fs = require('fs');

let app;

const initFirebaseAdmin = () => {
  try {
    const serviceAccountPath = path.join(__dirname, 'firebase', 'serviceAccountKey.json');
    
    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = require(serviceAccountPath);
      app = initializeApp({
        credential: cert(serviceAccount)
      });
      console.log('Firebase initialized successfully');
    } else {
      // Fallback to Application Default Credentials
      app = initializeApp();
      console.log('Firebase initialized successfully using Application Default Credentials');
    }
  } catch (error) {
    console.error('Firebase Admin SDK Initialization Error:', error.message);
  }
};

const getApp = () => app;
const getAdmin = () => require('firebase-admin');

module.exports = { getApp, getAdmin, initFirebaseAdmin };
