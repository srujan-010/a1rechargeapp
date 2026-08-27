const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
const { resolveA1TopupOperatorCode: resolveProviderOperatorCode } = require('../utils/operatorMapper');

async function testRechargeOrderValidation(payload) {
  console.log(`\n====================================================`);
  console.log(`[TESTING PAYLOAD]`, JSON.stringify(payload, null, 2));

  let mobileNumber = payload.mobileNumber || payload.phoneNumber || payload.subscriberNumber || 'N/A';
  let {
    amount,
    amountPaise,
    operatorId,
    circleId,
    serviceType = 'mobile',
    planId,
    planName,
    planType,
    selectedCategory,
    providerOperatorCode: reqProviderOpCode,
  } = payload;

  if (amountPaise && !amount) {
    amount = amountPaise / 100;
  }
  amount = amount || 0;

  if (typeof planId === 'string' && planId.trim() === '') {
    planId = null;
  }

  const rawOpCode = payload.operatorCode || reqProviderOpCode;
  const effectiveOperatorId = (operatorId && String(operatorId).trim() !== '')
    ? operatorId
    : (rawOpCode || payload.operatorName);

  if (!mobileNumber || mobileNumber === 'N/A' || !amount || amount <= 0 || !effectiveOperatorId) {
    console.error(`REJECTED: Missing or invalid required fields (400 INVALID_PAYLOAD)`);
    return false;
  }

  let operator;
  if (operatorId && mongoose.Types.ObjectId.isValid(operatorId)) {
    operator = await ProviderOperator.findById(operatorId);
  }
  if (!operator && effectiveOperatorId) {
    const codeLookup = String(effectiveOperatorId || '').toUpperCase().trim();
    operator = await ProviderOperator.findOne({ code: codeLookup });
  }
  if (!operator && rawOpCode) {
    const codeLookup = String(rawOpCode).toUpperCase().trim();
    operator = await ProviderOperator.findOne({ code: codeLookup });
  }
  if (!operator && (payload.operatorName || effectiveOperatorId)) {
    const searchWord = String(payload.operatorName || effectiveOperatorId).trim().split(' ')[0];
    operator = await ProviderOperator.findOne({ name: new RegExp(searchWord, 'i') });
  }

  if (!operator || !operator.status) {
    console.error(`REJECTED: Invalid or disabled operator ID '${operatorId || effectiveOperatorId}' (400 INVALID_OPERATOR)`);
    return false;
  }

  let operatorCode = operator.code;
  const providerOperatorCode = resolveProviderOperatorCode({
    operator,
    operatorId: operator._id.toString(),
    operatorName: payload.operatorName || operator.name,
    planType,
    selectedCategory,
    planName,
    providerOperatorCode: reqProviderOpCode || rawOpCode,
  });
  if (operator.serviceType?.toUpperCase() !== 'DTH' && serviceType !== 'dth') {
    operatorCode = providerOperatorCode;
  }

  let circle;
  if (circleId && mongoose.Types.ObjectId.isValid(circleId)) {
    circle = await ProviderCircle.findById(circleId);
  } else if (circleId) {
    circle = await ProviderCircle.findOne({ code: String(circleId).trim() });
  }
  if (!circle) {
    circle = await ProviderCircle.findOne({ code: '4' });
  }
  const circleCode = circle ? circle.code : '4';

  console.log(`RESOLVED SUCCESS:`);
  console.log(`- Operator: ${operator.name} (id: ${operator._id})`);
  console.log(`- OperatorCode: ${operatorCode}`);
  console.log(`- ProviderOperatorCode: ${providerOperatorCode}`);
  console.log(`- CircleCode: ${circleCode}`);
  console.log(`- PlanId: ${planId}`);
  return true;
}

async function run() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);

  // Test BSNL GSM (Flutter sends operatorId: "", operatorCode: "4", operatorName: "BSNL GSM", amountPaise: 1000)
  await testRechargeOrderValidation({
    mobileNumber: '9421729714',
    operatorId: '',
    operatorCode: '4',
    operatorName: 'BSNL GSM',
    circleId: 'maharashtra',
    serviceType: 'mobile',
    amountPaise: 1000,
    planId: '',
  });

  // Test Airtel
  await testRechargeOrderValidation({
    mobileNumber: '9440751149',
    operatorId: '6a5f13a926991fd97d8629f4',
    operatorName: 'Airtel',
    circleId: '4',
    serviceType: 'mobile',
    amountPaise: 1000,
    planId: '',
  });

  // Test Jio
  await testRechargeOrderValidation({
    mobileNumber: '9876543210',
    operatorId: '6a5f13a926991fd97d8629f7',
    operatorName: 'RELIANCE - JIO',
    circleId: '4',
    serviceType: 'mobile',
    amountPaise: 1000,
    planId: '',
  });

  // Test Vi
  await testRechargeOrderValidation({
    mobileNumber: '9876543211',
    operatorId: '6a5f13a926991fd97d8629f5',
    operatorName: 'Vodafone',
    circleId: '4',
    serviceType: 'mobile',
    amountPaise: 1000,
    planId: '',
  });

  await mongoose.disconnect();
}

run().catch(console.error);
