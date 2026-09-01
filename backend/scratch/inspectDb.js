const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

(async () => {
  try {
    const mongoUri = process.env.MONGODB_URI;
    console.log('Connecting to:', mongoUri ? mongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE');
    await mongoose.connect(mongoUri);
    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log('\n--- COLLECTIONS COUNT ---');
    for (const c of collections) {
      const count = await mongoose.connection.db.collection(c.name).countDocuments();
      console.log(`${c.name}: ${count} documents`);
    }
    console.log('-------------------------\n');
  } catch (e) {
    console.error('DB Check Error:', e);
  } finally {
    await mongoose.disconnect();
  }
})();
