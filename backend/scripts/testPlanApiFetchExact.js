const axios = require('axios');

async function testFetch() {
  const PLANAPI_MEMBER_ID = '7315';
  const PLANAPI_PASSWORD = 'A1recharge';
  
  // Test MSEDC bill fetch exactly as service does now
  const url = `https://planapi.in/api/Mobile/ElectricityBillFetch?apimember_id=${PLANAPI_MEMBER_ID}&api_password=${PLANAPI_PASSWORD}&operator_code=131&bill_number=476020101151`;
  
  console.log('Fetching:', url.replace(PLANAPI_PASSWORD, '***').replace(PLANAPI_MEMBER_ID, '***'));
  
  try {
    const res = await axios.get(url, {
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'A1Recharge-Backend/1.0',
        'Connection': 'keep-alive'
      }
    });
    console.log('Status:', res.status);
    console.log('Body:', JSON.stringify(res.data, null, 2));
  } catch (error) {
    if (error.response) {
      console.log('Error Status:', error.response.status);
      console.log('Error Body:', error.response.data);
    } else {
      console.log('Error Message:', error.message);
    }
  }
}

testFetch();
