require('dotenv').config();
const mongoose = require('mongoose');
const reconciliationService = require('../services/reconciliation/reconciliation.service');

async function run() {
  try {
    const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge';
    console.log(`[RECONCILIATION SCRIPT] Connecting to MongoDB...`);
    await mongoose.connect(mongoUri);

    console.log(`[RECONCILIATION SCRIPT] Running wallet audit...`);
    const results = await reconciliationService.reconcileAllWallets();

    console.log(JSON.stringify(results, null, 2));

    await mongoose.disconnect();
    console.log(`[RECONCILIATION SCRIPT] Done.`);
    process.exit(0);
  } catch (err) {
    console.error(`[RECONCILIATION SCRIPT ERROR]:`, err);
    process.exit(1);
  }
}

run();
