const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const ProviderOperator = require('../models/ProviderOperator');
const { resolvePlansApiOperatorCode } = require('../utils/operatorMapper');

async function testObjectIdResolution() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('\n====================================================');
  console.log('[TESTING OBJECTID RESOLUTION FOR PLANSAPI]');

  const operators = await ProviderOperator.find({}).lean();
  for (const op of operators) {
    const mongoIdStr = op._id.toString();
    const resolvedTopup = resolvePlansApiOperatorCode(op, 'TOPUP');
    const resolvedSpecial = resolvePlansApiOperatorCode(op, 'SPECIAL');

    console.log(`Operator: "${op.name}" (code: "${op.code}", _id: ${mongoIdStr})`);
    console.log(`  -> Resolved for TOPUP: ${resolvedTopup}`);
    console.log(`  -> Resolved for SPECIAL: ${resolvedSpecial}`);
  }

  // Also test passing mongoIdStr directly
  console.log('\n[TESTING PASSING MONGO DB OBJECT IDs DIRECTLY AS STRINGS]');
  for (const op of operators) {
    const mongoIdStr = op._id.toString();
    let dbOp = await ProviderOperator.findById(mongoIdStr);
    const resolvedTopup = resolvePlansApiOperatorCode(dbOp, 'TOPUP');
    const resolvedSpecial = resolvePlansApiOperatorCode(dbOp, 'SPECIAL');

    console.log(`Input ObjectId string: ${mongoIdStr} (${dbOp.name})`);
    console.log(`  -> PlansAPI Code TOPUP: ${resolvedTopup}`);
    console.log(`  -> PlansAPI Code SPECIAL: ${resolvedSpecial}`);
  }

  console.log('====================================================\n');
  await mongoose.disconnect();
}

testObjectIdResolution().catch(console.error);
