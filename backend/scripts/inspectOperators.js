const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const ProviderOperator = require('../models/ProviderOperator');

async function inspectMobileOperators() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('\n====================================================');
  console.log('[MOBILE / PREPAID / DTH OPERATORS IN DB]');
  
  const ops = await ProviderOperator.find({}).lean();
  ops.filter(op => {
    const st = (op.serviceType || '').toUpperCase();
    return st.includes('MOBILE') || st.includes('PREPAID') || st.includes('DTH') || op.name.includes('BSNL') || op.name.includes('Airtel') || op.name.includes('Jio') || op.name.includes('Vi');
  }).forEach(op => {
    console.log(`- _id: ${op._id}, name: "${op.name}", code: "${op.code}", a1TopupCode: "${op.a1TopupCode}", serviceType: "${op.serviceType}", status: ${op.status}`);
  });

  console.log('====================================================\n');
  await mongoose.disconnect();
}

inspectMobileOperators().catch(console.error);
