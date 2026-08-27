const axios = require('axios');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const config = require('../config/a1topup.config');

async function testLiveConnection() {
  console.log('\n====================================================');
  console.log('[TESTING A1TOPUP ENVIRONMENT & CONFIG]');
  console.log(`A1TOPUP_BASE_URL: ${config.baseUrl}`);
  console.log(`A1TOPUP_USERNAME: ${config.username ? config.username : 'MISSING / UNDEFINED'}`);
  console.log(`A1TOPUP_PASSWORD: ${config.password ? '*** (SET)' : 'MISSING / UNDEFINED'}`);
  console.log(`A1TOPUP_FORMAT: ${config.format}`);
  console.log('====================================================\n');

  if (!config.username || !config.password) {
    console.error('CRITICAL: A1Topup username or password is missing in environment variables!');
    return;
  }

  const testOrderId = `A1RTEST${Date.now()}`;
  const payload = {
    username: config.username,
    pwd: config.password,
    format: config.format || 'json',
    number: '8275366399',
    amount: 10,
    operatorcode: 'BT',
    circlecode: '4',
    orderid: testOrderId,
  };

  const safeParams = {
    ...payload,
    username: config.username ? `${config.username.substring(0, 3)}***` : '***',
    pwd: '***',
  };

  console.log('[A1TOPUP LIVE HTTP REQUEST]');
  console.log(`URL: ${config.baseUrl}/recharge/api`);
  console.log(`Method: GET`);
  console.log(`Params:`, JSON.stringify(safeParams, null, 2));

  const startTime = Date.now();
  try {
    const client = axios.create({
      baseURL: config.baseUrl,
      timeout: 15000,
    });

    const response = await client.get('/recharge/api', { params: payload });
    const elapsedMs = Date.now() - startTime;

    console.log('\n====================================================');
    console.log('[A1TOPUP LIVE HTTP RESPONSE]');
    console.log(`httpStatus: ${response.status}`);
    console.log(`elapsedMs: ${elapsedMs}ms`);
    console.log(`rawBody:`, typeof response.data === 'object' ? JSON.stringify(response.data) : response.data);
    console.log('====================================================\n');

  } catch (error) {
    const elapsedMs = Date.now() - startTime;
    console.error('\n====================================================');
    console.error('[A1TOPUP LIVE HTTP ERROR]');
    console.error(`elapsedMs: ${elapsedMs}ms`);
    console.error(`errorType: ${error.code || error.name}`);
    console.error(`message: ${error.message}`);
    if (error.response) {
      console.error(`httpStatus: ${error.response.status}`);
      console.error(`responseBody:`, typeof error.response.data === 'object' ? JSON.stringify(error.response.data) : error.response.data);
    }
    console.error('====================================================\n');
  }
}

testLiveConnection().catch(console.error);
