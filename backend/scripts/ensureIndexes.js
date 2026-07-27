/**
 * backend/scripts/ensureIndexes.js
 * Creates performance indexes on MongoDB collections for < 50ms query speeds.
 */

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

const connectDB = require('../config/db');

async function createIndexes() {
  try {
    await connectDB();
    console.log('Building MongoDB performance indexes...');

    const db = mongoose.connection.db;

    // 1. Transactions index (userId + createdAt DESC)
    console.log('Indexing Transactions...');
    await db.collection('transactions').createIndex({ userId: 1, createdAt: -1 });
    await db.collection('transactions').createIndex({ referenceId: 1 }, { sparse: true });
    await db.collection('transactions').createIndex({ status: 1 });

    // 2. RechargeTransactions index
    console.log('Indexing RechargeTransactions...');
    await db.collection('rechargetransactions').createIndex({ userId: 1, createdAt: -1 });
    await db.collection('rechargetransactions').createIndex({ referenceId: 1 });
    await db.collection('rechargetransactions').createIndex({ status: 1 });

    // 3. Wallet Ledger index (walletId + createdAt DESC)
    console.log('Indexing WalletLedgers...');
    await db.collection('walletledgers').createIndex({ walletId: 1, createdAt: -1 });

    // 4. Users index
    console.log('Indexing Users...');
    await db.collection('users').createIndex({ mobileNumber: 1 });
    await db.collection('users').createIndex({ email: 1 }, { sparse: true });

    // 5. Notifications index
    console.log('Indexing Notifications...');
    await db.collection('notifications').createIndex({ userId: 1, createdAt: -1 });

    // 6. ProviderOperators index
    console.log('Indexing ProviderOperators...');
    await db.collection('provideroperators').createIndex({ serviceType: 1, isEnabled: 1 });

    console.log('✅ ALL MONGO DB INDEXES SUCCESSFULLY CREATED!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating indexes:', error);
    process.exit(1);
  }
}

createIndexes();
