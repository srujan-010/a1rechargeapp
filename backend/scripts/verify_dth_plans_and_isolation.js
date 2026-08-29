require('dotenv').config({ path: __dirname + '/../.env' });
const connectDB = require('../config/db');
const ProviderOperator = require('../models/ProviderOperator');
const { resolvePlansApiOperatorCode, resolveA1TopupOperatorCode } = require('../utils/operatorMapper');
const planApiService = require('../services/planapi.service');

async function runVerification() {
  await connectDB();
  console.log('==================================================');
  console.log('RUNNING DTH PLAN FETCHING & OPERATOR ISOLATION VERIFICATION');
  console.log('==================================================\n');

  const dthOperators = [
    { name: 'AIRTEL DTH', expectedPlanCode: '24', expectedA1Code: 'ATV' },
    { name: 'DISH TV', expectedPlanCode: '25', expectedA1Code: 'DTV' },
    { name: 'RELIANCE BIGTV', expectedPlanCode: '26', expectedA1Code: 'RBTV' },
    { name: 'SUN DIRECT', expectedPlanCode: '27', expectedA1Code: 'STV' },
    { name: 'TATA SKY', expectedPlanCode: '28', expectedA1Code: 'TTV' },
    { name: 'VIDEOCON D2H', expectedPlanCode: '29', expectedA1Code: 'VTV' },
  ];

  for (const item of dthOperators) {
    const opDoc = await ProviderOperator.findOne({ serviceType: /^DTH$/i, name: item.name }).lean();
    if (!opDoc) {
      console.error(`❌ FAILED: Operator document for ${item.name} not found in DB!`);
      process.exit(1);
    }

    const resolvedPlanCode = resolvePlansApiOperatorCode(opDoc);
    const resolvedA1Code = resolveA1TopupOperatorCode({ operator: opDoc });

    console.log(`[DTH VERIFICATION] Operator: ${opDoc.name}`);
    console.log(`  - DB ID: ${opDoc._id}`);
    console.log(`  - DB plansApiCode: ${opDoc.plansApiCode}`);
    console.log(`  - DB code/a1TopupCode: ${opDoc.code} / ${opDoc.a1TopupCode}`);
    console.log(`  - Resolved PlansAPI Code: ${resolvedPlanCode} (Expected: ${item.expectedPlanCode})`);
    console.log(`  - Resolved A1Topup Code: ${resolvedA1Code} (Expected: ${item.expectedA1Code})`);

    if (resolvedPlanCode !== item.expectedPlanCode) {
      console.error(`❌ FAILED: PlanAPI Code mismatch for ${item.name}! Got ${resolvedPlanCode}, expected ${item.expectedPlanCode}`);
      process.exit(1);
    }

    if (resolvedA1Code !== item.expectedA1Code) {
      console.error(`❌ FAILED: A1Topup Code mismatch for ${item.name}! Got ${resolvedA1Code}, expected ${item.expectedA1Code}`);
      process.exit(1);
    }

    console.log(`  ✅ ${item.name} isolated & mapped correctly!\n`);
  }

  // BSNL Verification
  console.log('==================================================');
  console.log('BSNL OPERATOR INDEPENDENCE VERIFICATION');
  console.log('==================================================\n');

  const bsnlTopup = await ProviderOperator.findOne({ code: 'BT' }).lean();
  const bsnlSpecial = await ProviderOperator.findOne({ code: 'BR' }).lean();

  if (!bsnlTopup || !bsnlSpecial) {
    console.error('❌ FAILED: BSNL TOPUP or BSNL SPECIAL document missing in DB!');
    process.exit(1);
  }

  console.log(`BSNL TOPUP: Name=${bsnlTopup.name}, Code=${bsnlTopup.code}, PlansAPI=${resolvePlansApiOperatorCode(bsnlTopup)}`);
  console.log(`BSNL SPECIAL: Name=${bsnlSpecial.name}, Code=${bsnlSpecial.code}, PlansAPI=${resolvePlansApiOperatorCode(bsnlSpecial)}`);

  if (bsnlTopup.name !== 'BSNL TOPUP' || bsnlSpecial.name !== 'BSNL SPECIAL') {
    console.error('❌ FAILED: BSNL Display names incorrect!');
    process.exit(1);
  }

  if (resolvePlansApiOperatorCode(bsnlTopup) !== '4' || resolvePlansApiOperatorCode(bsnlSpecial) !== '5') {
    console.error('❌ FAILED: BSNL PlanAPI codes incorrect!');
    process.exit(1);
  }

  if (resolveA1TopupOperatorCode({ operator: bsnlTopup }) !== 'BT' || resolveA1TopupOperatorCode({ operator: bsnlSpecial, planType: 'STV' }) !== 'BR') {
    console.error('❌ FAILED: BSNL A1Topup recharge codes changed!');
    process.exit(1);
  }

  console.log('  ✅ BSNL TOPUP & BSNL SPECIAL display names & independent behavior verified!\n');

  console.log('==================================================');
  console.log('ALL DTH & OPERATOR ISOLATION VERIFICATIONS PASSED SUCCESSFULLY!');
  console.log('==================================================');
  process.exit(0);
}

runVerification();
