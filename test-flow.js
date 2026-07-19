const http = require('http');

async function run() {
  try {
    // 1. Send OTP
    const sendOtpRes = await fetch('http://localhost:5000/api/auth/send-otp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '9100329521' })
    });
    const sendOtpData = await sendOtpRes.json();
    console.log('Send OTP:', sendOtpData);

    const otp = sendOtpData.data.otp;

    // 2. Verify OTP
    const verifyOtpRes = await fetch('http://localhost:5000/api/auth/verify-otp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '9100329521', otp })
    });
    const verifyOtpData = await verifyOtpRes.json();
    console.log('Verify OTP Status:', verifyOtpRes.status);
    console.log('Verify OTP:', verifyOtpData);

    const token = verifyOtpData.data.accessToken;

    // 3. Setup MPIN
    const setupMpinRes = await fetch('http://localhost:5000/api/auth/setup-mpin', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + token
      },
      body: JSON.stringify({ mpin: '123456' })
    });
    const setupMpinData = await setupMpinRes.json();
    console.log('Setup MPIN Status:', setupMpinRes.status);
    console.log('Setup MPIN:', setupMpinData);
  } catch (err) {
    console.error('Error:', err);
  }
}

run();
