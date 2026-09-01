const { assertTestEnvironment } = require('./testDbGuard');

// Force process.env URIs to local isolated test database for Jest runner
process.env.MONGODB_URI = 'mongodb://localhost:27017/a1recharge_test';
process.env.MONGO_URI = 'mongodb://localhost:27017/a1recharge_test';
process.env.NODE_ENV = 'test';

assertTestEnvironment(process.env.MONGODB_URI);
console.log('\n[JEST SETUP GUARD] Environment locked to: mongodb://localhost:27017/a1recharge_test\n');
