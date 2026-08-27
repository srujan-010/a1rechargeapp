const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const ProviderOperator = require('../models/ProviderOperator');

async function inspectBsnl() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('\n====================================================');
  console.log('[INSPECT BSNL PROVIDER OPERATOR DOCUMENTS]');

  const ops = await ProviderOperator.find({ $or: [{ name: /bsnl/i }, { code: 'BT' }, { code: 'BR' }] }).lean();
  console.log(`Found ${ops.length} BSNL operator documents:`);
  ops.forEach(op => {
    console.log(`- _id: ${op._id}, name: "${op.name}", code: "${op.code}", a1TopupCode: "${op.a1TopupCode}", plansApiCode: "${op.plansApiCode}", serviceType: "${op.serviceType}"`);
  });

  console.log('====================================================\n');
  await mongoose.disconnect();
}

inspectBsnl().catch(console.error);
