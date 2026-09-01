const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function restoreToTempDatabase() {
  const localMongoUri = 'mongodb://localhost:27017/a1recharge_restore_verify';
  console.log('\n[RESTORE STEP 2] Restoring snapshot to isolated temporary database:', localMongoUri);

  const archivePath = path.join(__dirname, '../a1recharge_pre_restore_backup_20260901.gz');
  if (!fs.existsSync(archivePath)) {
    throw new Error(`Backup archive not found at: ${archivePath}`);
  }

  const compressedBuffer = fs.readFileSync(archivePath);
  const jsonString = zlib.gunzipSync(compressedBuffer).toString('utf-8');
  const backupData = JSON.parse(jsonString);

  console.log(`[RESTORE STEP 2] Backup timestamp: ${backupData.metadata.createdAt}`);
  console.log(`[RESTORE STEP 2] Restoring ${backupData.metadata.collectionCount} collections to a1recharge_restore_verify...`);

  await mongoose.connect(localMongoUri);
  const tempDb = mongoose.connection.db;

  for (const [colName, docs] of Object.entries(backupData.collections)) {
    const col = tempDb.collection(colName);
    await col.deleteMany({});
    if (docs && docs.length > 0) {
      // Re-hydrate ObjectIds and Dates
      const hydratedDocs = docs.map(doc => {
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
    console.log(`  Restored to temp DB [${colName}]: ${docs.length} documents`);
  }

  console.log('\n====================================================');
  console.log('[SNAPSHOT SUCCESSFULLY RESTORED TO TEMPORARY DATABASE]');
  console.log(`Temporary Database URI: ${localMongoUri}`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreToTempDatabase().catch(err => {
    console.error('Temp DB restoration error:', err);
    process.exit(1);
  });
}

module.exports = { restoreToTempDatabase };
