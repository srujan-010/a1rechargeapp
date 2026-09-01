const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const syntheticTestPhones = ['9999999999', '9888877777', '9999900000', '9999000001', '9999000002'];
const syntheticTestOrders = ['A1R178827858563484', 'A1R1788278586607132', 'A1R1788278586820353'];

async function executeProductionRestore() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('[PROD RESTORE] Connecting to Production Atlas database:', prodMongoUri ? prodMongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE');

  const archivePath = path.join(__dirname, '../a1recharge_pre_restore_backup_20260901.gz');
  const compressedBuffer = fs.readFileSync(archivePath);
  const jsonString = zlib.gunzipSync(compressedBuffer).toString('utf-8');
  const backupData = JSON.parse(jsonString);

  await mongoose.connect(prodMongoUri);
  const db = mongoose.connection.db;

  console.log(`[PROD RESTORE] Restoring ${backupData.metadata.collectionCount} collections into Production database [${db.databaseName}]...`);

  for (const [colName, docs] of Object.entries(backupData.collections)) {
    const col = db.collection(colName);

    // Filter synthetic test fixtures
    let cleanDocs = docs || [];

    if (colName === 'users') {
      cleanDocs = cleanDocs.filter(d => !syntheticTestPhones.includes(d.phone));
    } else if (colName === 'rechargetransactions') {
      cleanDocs = cleanDocs.filter(d => !syntheticTestOrders.includes(d.orderId));
    }

    await col.deleteMany({});

    if (cleanDocs.length > 0) {
      const hydratedDocs = cleanDocs.map(doc => {
        const copy = { ...doc };
        if (copy._id && typeof copy._id === 'string' && copy._id.match(/^[0-9a-fA-F]{24}$/)) {
          copy._id = new mongoose.Types.ObjectId(copy._id);
        }
        if (copy.userId && typeof copy.userId === 'string' && copy.userId.match(/^[0-9a-fA-F]{24}$/)) {
          copy.userId = new mongoose.Types.ObjectId(copy.userId);
        }
        return copy;
      });
      await col.insertMany(hydratedDocs);
    }

    console.log(`  Restored production collection [${colName}]: ${cleanDocs.length} documents`);
  }

  console.log('\n====================================================');
  console.log('[PRODUCTION DATABASE RESTORATION EXECUTED SUCCESSFULLY]');
  console.log(`Target Database: ${db.databaseName}`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  executeProductionRestore().catch(err => {
    console.error('Production Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { executeProductionRestore };
