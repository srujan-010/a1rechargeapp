const { resolvePlansApiOperatorCode, resolveA1TopupOperatorCode } = require('../utils/operatorMapper');

console.log('\n====================================================');
console.log('[TESTING PLANSAPI VS A1TOPUP OPERATOR RESOLUTION]');

// Test 1: BSNL TOPUP PlansAPI
const t1 = resolvePlansApiOperatorCode('BSNL', 'TOPUP');
console.log(`TEST 1: BSNL TOPUP -> PlansAPI code: ${t1} (Expected: 4)`);

// Test 2: BSNL SPECIAL PlansAPI
const t2 = resolvePlansApiOperatorCode('BSNL', 'SPECIAL');
console.log(`TEST 2: BSNL SPECIAL -> PlansAPI code: ${t2} (Expected: 5)`);

// Test 3: Airtel PlansAPI
const t3 = resolvePlansApiOperatorCode('Airtel');
console.log(`TEST 3: Airtel -> PlansAPI code: ${t3} (Expected: 2)`);

// Test 4: Vodafone/Vi PlansAPI
const t4 = resolvePlansApiOperatorCode('Vodafone');
console.log(`TEST 4: Vodafone -> PlansAPI code: ${t4} (Expected: 23)`);

// Test 5: A1Topup BSNL Recharge Execution
const t5a = resolveA1TopupOperatorCode({ operator: { name: 'BSNL', code: 'BT' }, planType: 'TOPUP' });
console.log(`TEST 5a: A1Topup BSNL TOPUP Recharge -> A1Topup code: ${t5a} (Expected: BT)`);

const t5b = resolveA1TopupOperatorCode({ operator: { name: 'BSNL', code: 'BR' }, planType: 'SPECIAL' });
console.log(`TEST 5b: A1Topup BSNL SPECIAL Recharge -> A1Topup code: ${t5b} (Expected: BR)`);

console.log('====================================================\n');
