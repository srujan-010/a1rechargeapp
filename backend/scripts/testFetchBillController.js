const axios = require('axios');

async function run() {
  try {
    const payload = {
      billerId: 131,
      parameters: {
        bill_number: "476020101151"
      }
    };
    
    console.log('Sending payload:', payload);
    const response = await axios.post('http://localhost:5000/api/electricity/fetch', payload);
    console.log('Response Status:', response.status);
    console.log('Response Body:', response.data);
  } catch (error) {
    if (error.response) {
      console.log('Error Status:', error.response.status);
      console.log('Error Body:', error.response.data);
    } else {
      console.log('Error Message:', error.message);
    }
  }
}

run();
