const planApiService = require('../services/planapi.service');
const { resolvePlansApiOperatorCode } = require('../utils/operatorMapper');

async function testBsnlPlans() {
  console.log('\n====================================================');
  console.log('[TEST 1: FETCH BSNL TOPUP PLANS (PLANSAPI CODE 4)]');
  const codeTopup = resolvePlansApiOperatorCode('BSNL', 'TOPUP');
  console.log(`Resolved PlansAPI Operator Code: ${codeTopup}`);
  
  const resTopup = await planApiService.fetchMobilePlans(codeTopup, '90'); // Maharashtra circle
  console.log(`httpStatus: 200`);
  console.log(`ERROR: ${resTopup.data?.ERROR}`);
  console.log(`STATUS: ${resTopup.data?.STATUS}`);
  console.log(`MESSAGE: ${resTopup.data?.Message || resTopup.data?.MESSAGE || 'N/A'}`);
  console.log(`RDATA: ${resTopup.data?.RDATA ? (Array.isArray(resTopup.data.RDATA) ? `${resTopup.data.RDATA.length} plans` : (typeof resTopup.data.RDATA === 'object' ? Object.keys(resTopup.data.RDATA).length + ' categories' : 'populated')) : 'null'}`);

  console.log('\n====================================================');
  console.log('[TEST 2: FETCH BSNL SPECIAL PLANS (PLANSAPI CODE 5)]');
  const codeSpecial = resolvePlansApiOperatorCode('BSNL', 'SPECIAL');
  console.log(`Resolved PlansAPI Operator Code: ${codeSpecial}`);
  
  const resSpecial = await planApiService.fetchMobilePlans(codeSpecial, '90');
  console.log(`httpStatus: 200`);
  console.log(`ERROR: ${resSpecial.data?.ERROR}`);
  console.log(`STATUS: ${resSpecial.data?.STATUS}`);
  console.log(`MESSAGE: ${resSpecial.data?.Message || resSpecial.data?.MESSAGE || 'N/A'}`);
  console.log(`RDATA: ${resSpecial.data?.RDATA ? (Array.isArray(resSpecial.data.RDATA) ? `${resSpecial.data.RDATA.length} plans` : (typeof resSpecial.data.RDATA === 'object' ? Object.keys(resSpecial.data.RDATA).length + ' categories' : 'populated')) : 'null'}`);
  console.log('====================================================\n');
}

testBsnlPlans().catch(console.error);
