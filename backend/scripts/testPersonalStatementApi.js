const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const Transaction = require('../models/Transaction');
const RechargeTransaction = require('../models/RechargeTransaction');
const walletController = require('../controllers/walletController');
const personalController = require('../controllers/personalController');

async function testPersonalHistory() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('[DB CONNECTED]');

  const testUserId = '6a8c238da11c66be44e44ee2';
  const req = {
    user: {
      _id: new mongoose.Types.ObjectId(testUserId),
      accountType: 'PERSONAL',
      phone: '9100329521',
    },
    query: { page: 1, limit: 20 },
  };

  let responseData = null;
  const res = {
    statusCode: 200,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(data) {
      responseData = data;
      return this;
    },
  };

  console.log('\n--- TESTING walletController.getStatement for Personal User ---');
  await walletController.getStatement(req, res, (err) => { console.error('Next err:', err); });
  console.log('HTTP status:', res.statusCode);
  console.log('Success:', responseData?.success);
  console.log('Returned transaction count:', responseData?.data?.length);
  if (responseData?.data) {
    responseData.data.forEach((t, i) => {
      console.log(` ${i+1}. [${t.status}] ID: ${t.id} Ref: ${t.referenceNumber} Mobile: ${t.customerIdentifier} Amount: ₹${(t.amount/100).toFixed(2)} Service: ${t.serviceType}`);
    });
  }

  console.log('\n--- TESTING personalController.getPersonalTransactions ---');
  await personalController.getPersonalTransactions(req, res, (err) => { console.error('Next err:', err); });
  console.log('HTTP status:', res.statusCode);
  console.log('Success:', responseData?.success);
  console.log('Returned transaction count:', responseData?.data?.length);

  await mongoose.disconnect();
  console.log('\n[TEST COMPLETED]');
}

testPersonalHistory().catch(console.error);
