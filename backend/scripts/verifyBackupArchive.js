const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');

async function verifyBackup() {
  const archivePath = path.join(__dirname, '../a1recharge_pre_restore_backup_20260901.gz');
  console.log('[VERIFY BACKUP] Checking file:', archivePath);

  if (!fs.existsSync(archivePath)) {
    throw new Error(`Backup file missing at: ${archivePath}`);
  }

  const fileStats = fs.statSync(archivePath);
  const compressedBuffer = fs.readFileSync(archivePath);
  const hash = crypto.createHash('sha256').update(compressedBuffer).digest('hex');

  // Verify readable & uncorrupted by un-zipping
  const uncompressedJson = zlib.gunzipSync(compressedBuffer).toString('utf-8');
  const backupObj = JSON.parse(uncompressedJson);

  console.log('====================================================');
  console.log('[PRE-RESTORE BACKUP ARCHIVE VERIFIED 100% INTINT & VALID]');
  console.log(`Path: ${archivePath}`);
  console.log(`Size: ${fileStats.size} bytes (${(fileStats.size / 1024).toFixed(2)} KB)`);
  console.log(`Backup Timestamp: ${backupObj.metadata.createdAt}`);
  console.log(`Collections Count: ${backupObj.metadata.collectionCount}`);
  console.log(`SHA256 Checksum: ${hash}`);
  console.log('====================================================\n');

  return {
    path: archivePath,
    size: fileStats.size,
    timestamp: backupObj.metadata.createdAt,
    checksum: hash,
    isValid: true,
  };
}

if (require.main === module) {
  verifyBackup().catch(err => {
    console.error('Backup Verification Failed:', err);
    process.exit(1);
  });
}

module.exports = { verifyBackup };
