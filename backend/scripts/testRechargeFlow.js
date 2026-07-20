const mongoose = require('mongoose');
const dotenv = require('dotenv');
const connectDB = require('../config/db');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');
const ProviderWallet = require('../models/ProviderWallet');
const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
const RechargeTransaction = require('../models/RechargeTransaction');

dotenv.config();

const runTest = async () => {
  try {
    await connectDB();
    console.log('--- STARTING RECHARGE RUNTIME PROOF ---');

    let balanceBefore = { balance: 'Unknown' };
    try {
      balanceBefore = await a1TopupProvider.balance();
      console.log(`Balance Before: ₹${balanceBefore.balance}`);
    } catch (e) {
      console.log(`Balance Before Check Failed: ${e.message}`);
    }

    // 2. Resolve Operator and Circle
    console.log('\n[2] Resolving JIO in Maharashtra...');
    const operator = await ProviderOperator.findOne({ code: 'RC' });
    const circle = await ProviderCircle.findOne({ code: '4' });
    console.log(`Resolved Operator: ${operator.name} (Code: ${operator.code})`);
    console.log(`Resolved Circle: ${circle.state} (Code: ${circle.code})`);

    // 3. Initiate Recharge
    console.log('\n[3] Initiating Live API Request...');
    const orderId = `TEST_A1R${Date.now()}`;
    const amount = 10; // 10 INR recharge
    const mobileNumber = '9999999999';

    // The recharge function contains console.logs for URL, method, payload, status, and raw body
    const providerResponse = await a1TopupProvider.recharge({
      orderId,
      mobileNumber,
      amount,
      operatorCode: operator.code,
      circleCode: circle.code,
    });

    // 4. Show Parsed Response
    console.log('\n[4] Parsed Normalized Response:');
    console.log(JSON.stringify(providerResponse, null, 2));

    // 5. Save to DB simulating controller
    console.log('\n[5] Saving to MongoDB RechargeTransaction...');
    const transaction = await RechargeTransaction.create({
      orderId,
      userId: new mongoose.Types.ObjectId(), // Dummy user
      providerName: 'A1Topup',
      mobileNumber,
      amount,
      operatorCode: operator.code,
      circleCode: circle.code,
      status: providerResponse.status,
      reservedAmount: amount,
      providerTransactionId: providerResponse.providerTransactionId,
      operatorReference: providerResponse.operatorReference,
      failureReason: providerResponse.status === 'FAILED' ? providerResponse.message : null,
    });
    
    console.log(JSON.stringify(transaction.toObject(), null, 2));

    let balanceAfter = { balance: 'Unknown' };
    try {
      balanceAfter = await a1TopupProvider.balance();
      console.log(`Balance After: ₹${balanceAfter.balance}`);
    } catch (e) {
      console.log(`Balance After Check Failed: ${e.message}`);
    }
    
    console.log('\n--- END OF RUNTIME PROOF ---');
    process.exit(0);
  } catch (error) {
    console.error('\nERROR DURING PROOF:', error.message);
    if (error.response) {
       console.error('Response:', error.response.data);
    }
    process.exit(1);
  }
};

runTest();
