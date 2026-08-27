const { initializeApp, cert } = require('firebase-admin/app');
const path = require('path');
const fs = require('fs');

let app;

const initFirebaseAdmin = () => {
  try {
    const serviceAccountPath = path.join(__dirname, 'firebase', 'serviceAccountKey.json');
    
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      try {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        app = initializeApp({
          credential: cert(serviceAccount)
        });
        console.log('[Firebase Admin] Initialized via FIREBASE_SERVICE_ACCOUNT env var');
        return;
      } catch (jsonErr) {
        console.error('[Firebase Admin] Failed to parse FIREBASE_SERVICE_ACCOUNT env var:', jsonErr.message);
      }
    }

    if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY) {
      app = initializeApp({
        credential: cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
          privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
        })
      });
      console.log('[Firebase Admin] Initialized via FIREBASE_PROJECT_ID env vars');
      return;
    }

    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = require(serviceAccountPath);
      app = initializeApp({
        credential: cert(serviceAccount)
      });
      console.log('[Firebase Admin] Initialized via local serviceAccountKey.json');
      return;
    }

    if (process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.FIREBASE_PROJECT_ID) {
      app = initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID
      });
      console.log('[Firebase Admin] Initialized using Application Default Credentials / Project ID');
      return;
    }

    console.warn('[Firebase Admin WARNING] No Firebase service account credentials or Project ID detected in environment. FCM push notifications disabled.');
  } catch (error) {
    console.error('Firebase Admin SDK Initialization Error:', error.message);
  }
};

const getApp = () => app;
const getAdmin = () => require('firebase-admin');

module.exports = { getApp, getAdmin, initFirebaseAdmin };
