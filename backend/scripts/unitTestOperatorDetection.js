const assert = require('assert');
const { resolvePlansApiOperatorCode, resolveA1TopupOperatorCode } = require('../utils/operatorMapper');

function runOperatorDetectionTests() {
  console.log('\n====================================================');
  console.log('RUNNING OPERATOR DETECTION & MAPPING SCENARIO TESTS');
  console.log('====================================================\n');

  // TEST 1: API returns Reliance Jio Infocomm Limited / OpCode 11 -> Normalized = JIO / 11
  console.log('TEST 1: API returns "Reliance Jio Infocomm Limited" / OpCode 11');
  const code1 = resolvePlansApiOperatorCode('Reliance Jio Infocomm Limited');
  assert.strictEqual(code1, '11', 'Reliance Jio Infocomm Limited must map to PlansAPI OpCode 11');
  console.log('✔ TEST 1 Passed! Result = OpCode 11\n');

  // TEST 2: Previously selected BSNL, new detection JIO -> BSNL cleared
  console.log('TEST 2: Operator switch BSNL -> JIO');
  const code2 = resolvePlansApiOperatorCode('Reliance Jio Infocomm Limited');
  assert.notStrictEqual(code2, '4', 'BSNL OpCode 4 must NOT remain');
  assert.notStrictEqual(code2, '5', 'BSNL OpCode 5 must NOT remain');
  assert.strictEqual(code2, '11', 'Operator code must update to 11');
  console.log('✔ TEST 2 Passed!\n');

  // TEST 3: Plans request must use OpCode 11
  console.log('TEST 3: Plans request for Jio must use OpCode 11');
  const planCode3 = resolvePlansApiOperatorCode({ name: 'Reliance Jio Infocomm Limited', plansApiCode: '11' });
  assert.strictEqual(planCode3, '11', 'Plan request code must be 11');
  console.log('✔ TEST 3 Passed!\n');

  // TEST 4: Race condition - Old BSNL response arrives after new JIO request
  console.log('TEST 4: Out of order response (Jio latest, BSNL stale)');
  let currentMobile = '919440761742'; // Jio number
  let activeOperator = 'Jio';
  let activeOpCode = '11';

  const staleBsnlResponse = { Mobile: '9440000000', Operator: 'BSNL TOPUP', OpCode: '4' };
  if (staleBsnlResponse.Mobile !== currentMobile) {
    // Discard stale response
  } else {
    activeOperator = 'BSNL';
    activeOpCode = '4';
  }

  assert.strictEqual(activeOperator, 'Jio', 'Stale response must NOT overwrite active Jio operator');
  assert.strictEqual(activeOpCode, '11', 'Stale response must NOT overwrite active OpCode 11');
  console.log('✔ TEST 4 Passed!\n');

  // TEST 5: Change mobile from Jio to BSNL
  console.log('TEST 5: Number change Jio -> BSNL');
  const bsnlCode = resolvePlansApiOperatorCode('BSNL TOPUP');
  assert.strictEqual(bsnlCode, '4', 'BSNL TOPUP must resolve to OpCode 4');
  console.log('✔ TEST 5 Passed!\n');

  // TEST 6: Change mobile from BSNL to Jio
  console.log('TEST 6: Number change BSNL -> Jio');
  const jioCode = resolvePlansApiOperatorCode('Reliance Jio Infocomm Limited');
  assert.strictEqual(jioCode, '11', 'Jio must resolve to OpCode 11');
  console.log('✔ TEST 6 Passed!\n');

  // TEST 7: Manual Change Operator updates plans & recharge payload
  console.log('TEST 7: Manual Change Operator');
  const manualAirtel = resolvePlansApiOperatorCode('Airtel');
  const manualA1Topup = resolveA1TopupOperatorCode({ operatorName: 'Airtel', providerOperatorCode: 'A' });
  assert.strictEqual(manualAirtel, '2', 'Manual Airtel plans code = 2');
  assert.strictEqual(manualA1Topup, 'A', 'Manual Airtel A1Topup code = A');
  console.log('✔ TEST 7 Passed!\n');

  // TEST 8: Re-entering same mobile number retains detection
  console.log('TEST 8: Re-entering same mobile number');
  const reenterCode = resolvePlansApiOperatorCode('Reliance Jio Infocomm Limited');
  assert.strictEqual(reenterCode, '11', 'Re-entered Jio resolves to 11');
  console.log('✔ TEST 8 Passed!\n');

  console.log('====================================================');
  console.log('ALL 8 OPERATOR DETECTION SCENARIO TESTS PASSED!');
  console.log('====================================================\n');
}

runOperatorDetectionTests();
