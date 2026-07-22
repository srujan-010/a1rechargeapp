const axios = require('axios');

async function testFetch() {
  const PLANAPI_MEMBER_ID = '7315';
  const PLANAPI_PASSWORD = 'A1recharge';
  
  // Test MSEDC bill fetch
  const url = `https://planapi.in/api/Mobile/ElectricityBillFetch?apimember_id=${PLANAPI_MEMBER_ID}&api_password=${PLANAPI_PASSWORD}&operatorcode=131&number=476020101151`;
  
  console.log('Fetching:', url);
  
  try {
    const res = await axios.get(url, {
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'A1Recharge-Backend/1.0',
        'Connection': 'keep-alive'
      }
    });
    console.log('Status:', res.status);
    console.log('Body:', res.data);
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
