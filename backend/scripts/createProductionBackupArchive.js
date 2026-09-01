const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function createBackupArchive() {
  const mongoUri = process.env.MONGODB_URI;
  console.log('[BACKUP STEP 1] Connecting to Production Atlas Database read-only...');
  await mongoose.connect(mongoUri);

  const db = mongoose.connection.db;
  const dbName = db.databaseName;
  const collections = await db.listCollections().toArray();

  console.log(`[BACKUP STEP 1] Database: ${dbName} | Total Collections: ${collections.length}`);

  const backupData = {
    metadata: {
      dbName,
      createdAt: new Date().toISOString(),
      collectionCount: collections.length,
    },
    collections: {},
  };

  for (const c of collections) {
    const docs = await db.collection(c.name).find({}).toArray();
    backupData.collections[c.name] = docs;
    console.log(`  Archived ${c.name}: ${docs.length} documents`);
  }

  await mongoose.disconnect();

  const backupFileName = 'a1recharge_pre_restore_backup_20260901.gz';
  const backupFilePath = path.join(__dirname, '..', backupFileName);

  const jsonString = JSON.stringify(backupData);
  const compressedBuffer = zlib.gzipSync(Buffer.from(jsonString, 'utf-8'));
  fs.writeFileSync(backupFilePath, compressedBuffer);

  const fileStats = fs.statSync(backupFilePath);
  const hash = crypto.createHash('sha256').update(compressedBuffer).digest('hex');

  console.log('\n====================================================');
  console.log('[PERMANENT BACKUP ARCHIVE CREATED SUCCESSFULLY]');
  console.log(`Path: ${backupFilePath}`);
  console.log(`Size: ${fileStats.size} bytes (${(fileStats.size / 1024).toFixed(2)} KB)`);
  console.log(`Timestamp: ${backupData.metadata.createdAt}`);
  console.log(`SHA256 Checksum: ${hash}`);
  console.log('====================================================\n');

  return {
    path: backupFilePath,
    size: fileStats.size,
    timestamp: backupData.metadata.createdAt,
    checksum: hash,
  };
}

if (require.main === module) {
  createBackupArchive().catch(err => {
    console.error('Backup creation error:', err);
    process.exit(1);
  });
}

module.exports = { createBackupArchive };
