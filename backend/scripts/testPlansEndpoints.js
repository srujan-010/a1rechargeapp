const axios = require('axios');
const dotenv = require('dotenv');

dotenv.config({ path: '.env' });

const token = process.env.PLANSINFO_TOKEN;

if (!token) {
  console.error("No token found in .env");
  process.exit(1);
}

const endpoints = [
  {
    name: 'Prepaid',
    url: 'https://api.plansinfo.com/v4/mobile-plans.php',
    params: { token, operator: 'AT', circle: 'PB' }
  },
  {
    name: 'Postpaid',
    url: 'https://api2.plansinfo.com/v5/mobile/postpaid-plans',
    params: { token, operator: 'PAT', circle: 'PB' }
  },
  {
    name: 'DTH Packs',
    url: 'https://api2.plansinfo.com/v5/dth/packs',
    params: { token, operator: 'TTV' }
  },
  {
    name: 'DTH Pack Details',
    url: 'https://api2.plansinfo.com/v5/dth/pack',
    params: { token, operator: 'TTV', pack_id: 'some_pack_id' }
  },
  {
    name: 'DTH Ala Carte',
    url: 'https://api2.plansinfo.com/v5/dth/alacarte',
    params: { token, operator: 'TTV' }
  }
];

async function runTests() {
  for (const ep of endpoints) {
    console.log(`\n--- Testing ${ep.name} ---`);
    const searchParams = new URLSearchParams(ep.params);
    let fullUrl = `${ep.url}?${searchParams.toString()}`;
    const maskedUrl = fullUrl.replace(`token=${token}`, 'token=***');
    
    console.log(`[URL] ${maskedUrl}`);
    
    try {
      const response = await axios.get(ep.url, { params: ep.params });
      console.log(`[HTTP STATUS] ${response.status}`);
      let dataStr = JSON.stringify(response.data);
      if (dataStr.length > 500) {
        dataStr = dataStr.substring(0, 500) + '... (truncated)';
      }
      console.log(`[RESPONSE BODY] ${dataStr}`);
    } catch (error) {
      if (error.response) {
        console.log(`[HTTP STATUS] ${error.response.status}`);
        let dataStr = JSON.stringify(error.response.data);
        if (dataStr.length > 500) {
          dataStr = dataStr.substring(0, 500) + '... (truncated)';
        }
        console.log(`[RESPONSE BODY] ${dataStr}`);
      } else {
        console.log(`[ERROR] ${error.message}`);
      }
    }
  }
}

runTests();
