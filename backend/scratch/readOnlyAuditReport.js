const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

(async () => {
  try {
    const mongoUri = process.env.MONGODB_URI;
    console.log('--- READ-ONLY DATABASE AUDIT REPORT ---');
    console.log('Connecting to:', mongoUri ? mongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE');
    await mongoose.connect(mongoUri);

    const dbName = mongoose.connection.db.databaseName;
    console.log(`Database Name: ${dbName}`);

    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log(`Total Collections: ${collections.length}\n`);

    console.log('| Collection Name | Document Count |');
    console.log('|-----------------|----------------|');
    for (const c of collections) {
      const count = await mongoose.connection.db.collection(c.name).countDocuments();
      console.log(`| ${c.name.padEnd(15)} | ${String(count).padStart(14)} |`);
    }

  } catch (e) {
    console.error('Audit Report Error:', e);
  } finally {
    await mongoose.disconnect();
  }
})();
