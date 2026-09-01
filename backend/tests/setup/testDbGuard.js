const mongoose = require('mongoose');

/**
 * HARD SAFETY GATE FOR TEST SUITES
 * Absolutely prevents test suites from ever connecting to or mutating remote/production MongoDB databases.
 */
function assertTestEnvironment(uri) {
  const targetUri = uri || process.env.TEST_MONGODB_URI || 'mongodb://localhost:27017/a1recharge_test';

  if (!targetUri) {
    throw new Error('[FATAL SECURITY VIOLATION] No MongoDB URI provided to test runner.');
  }

  const isRemote =
    targetUri.includes('mongodb+srv://') ||
    targetUri.includes('mongodb.net') ||
    targetUri.includes('uxhkjxg') ||
    targetUri.includes('a1recharge.uxhkjxg.mongodb.net');

  if (isRemote) {
    console.error('\n====================================================');
    console.error('🚨 FATAL: TEST SUITE REFUSED TO CONNECT TO REMOTE/PRODUCTION MONGODB 🚨');
    console.error(`Attempted URI: ${targetUri}`);
    console.error('Test execution is strictly aborted to prevent production data corruption.');
    console.error('====================================================\n');
    throw new Error('[FATAL SECURITY VIOLATION] Test suite attempted to connect to remote/production MongoDBAtlas URI.');
  }

  return targetUri;
}

/**
 * Asserts current active mongoose connection is isolated to localhost a1recharge_test.
 */
function assertTestDatabaseConnection() {
  if (mongoose.connection.readyState === 0) {
    throw new Error('[FATAL SECURITY VIOLATION] Database connection is closed.');
  }

  const host = mongoose.connection.host || '';
  const dbName = mongoose.connection.name || '';

  const isLocal = host === 'localhost' || host === '127.0.0.1' || host === '::1';
  const isTestDb = dbName === 'a1recharge_test';

  if (!isLocal || !isTestDb) {
    console.error('\n====================================================');
    console.error('🚨 FATAL: DESTRUCTIVE OPERATION REFUSED ON NON-TEST DATABASE 🚨');
    console.error(`Host: ${host} | Database: ${dbName}`);
    console.error('====================================================\n');
    throw new Error(`[FATAL SECURITY VIOLATION] Refusing database operation on non-test database: ${host}/${dbName}`);
  }
}

/**
 * Safe connection helper for test suites.
 */
async function connectTestDb() {
  const uri = assertTestEnvironment('mongodb://localhost:27017/a1recharge_test');
  if (mongoose.connection.readyState === 0) {
    await mongoose.connect(uri);
  }
  assertTestDatabaseConnection();
  console.log(`[TEST DB GUARD] Connected safely to isolated test DB: ${mongoose.connection.host}/${mongoose.connection.name}`);
}

module.exports = {
  assertTestEnvironment,
  assertTestDatabaseConnection,
  connectTestDb,
};
