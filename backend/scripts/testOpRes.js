const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');

async function testOperatorResolution(operatorId, operatorCode, providerOperatorCode, operatorName) {
  console.log(`\nTesting operator resolution with: operatorId="${operatorId}", operatorCode="${operatorCode}", reqOpCode="${providerOperatorCode}", operatorName="${operatorName}"`);

  let operator;
  if (operatorId && mongoose.Types.ObjectId.isValid(operatorId)) {
    operator = await ProviderOperator.findById(operatorId);
    console.log(`1. findById(${operatorId}): ${operator ? operator.name : 'null'}`);
  }
  if (!operator) {
    const codeLookup = String(operatorId || providerOperatorCode || operatorCode || '').toUpperCase().trim();
    if (codeLookup) {
      // Try code lookup with and without provider field
      operator = await ProviderOperator.findOne({ code: codeLookup });
      console.log(`2. findOne({ code: '${codeLookup}' }): ${operator ? operator.name : 'null'}`);
    }
  }
  if (!operator && operatorName) {
    const firstWord = String(operatorName || '').trim().split(' ')[0];
    operator = await ProviderOperator.findOne({ name: new RegExp(firstWord, 'i') });
    console.log(`3. findOne({ name: /${firstWord}/i }): ${operator ? operator.name : 'null'}`);
  }

  console.log(`FINAL RESOLVED OPERATOR: ${operator ? `${operator.name} (code: ${operator.code}, id: ${operator._id})` : 'FAILED TO RESOLVE'}`);
}

async function run() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);

  // Test Case 1: BSNL with empty operatorId, operatorCode=4, operatorName="BSNL GSM"
  await testOperatorResolution("", "4", "4", "BSNL GSM");

  // Test Case 2: BSNL with operatorCode=BT
  await testOperatorResolution("", "BT", "BT", "BSNL");

  // Test Case 3: Airtel with ObjectId
  await testOperatorResolution("6a5f13a926991fd97d8629f4", "AT", "AT", "Airtel");

  // Test Case 4: Jio with operatorCode=JO
  await testOperatorResolution("", "JO", "RC", "RELIANCE - JIO");

  await mongoose.disconnect();
}

run().catch(console.error);
