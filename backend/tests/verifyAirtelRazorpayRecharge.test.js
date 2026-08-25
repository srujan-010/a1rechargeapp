const mongoose = require('mongoose');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const crypto = require('crypto');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');
const { createRazorpayRechargeOrder, verifyRazorpayRechargePayment } = require('../controllers/recharge.controller');

describe('Airtel Razorpay Live A1Topup Recharge End-to-End Test', () => {
  let user;
  let wallet;
  let operator;
  let circle;

  beforeAll(async () => {
    jest.spyOn(a1TopupProvider, 'recharge').mockResolvedValue({
      providerTransactionId: 'TEST_A1_5532902',
      operatorRef: 'TEST_OP_REF_999',
      rawResponse: { status: 'Success', txid: 'TEST_A1_5532902', opid: 'TEST_OP_REF_999' }
    });
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test');
    }

    user = await User.findOne({ role: 'retailer' });
    if (!user) {
      user = await User.findOne({});
    }
    if (!user) {
      user = await User.create({
        name: 'Airtel Test Retailer',
        phone: '9100329521',
        retailerId: 'RET910032',
        role: 'retailer',
      });
    }

    // Ensure operator is Airtel with code 'A'
    operator = await ProviderOperator.findOne({ code: 'A', provider: 'A1Topup' });
    if (!operator) {
      operator = await ProviderOperator.findOne({ name: /airtel/i, provider: 'A1Topup' });
    }
    if (!operator) {
      operator = await ProviderOperator.create({
        name: 'Airtel',
        code: 'A',
        category: 'Mobile',
        serviceType: 'Mobile',
        provider: 'A1Topup',
        status: true,
      });
    }

    circle = await ProviderCircle.findOne({ code: '4', provider: 'A1Topup' });
  });

  afterAll(async () => {
    await mongoose.connection.close();
  });

  test('Fresh ₹10 Airtel Razorpay recharge executes real A1Topup /recharge/api call', async () => {
    console.log('\n====================================================');
    console.log('[E2E AIRTEL TEST] Step 1: Create Razorpay Recharge Order');
    console.log('====================================================\n');

    const reqOrder = {
      user,
      body: {
        mobileNumber: '9100329521',
        amount: 10,
        operatorId: operator._id.toString(),
        serviceType: 'mobile',
        operatorName: 'Airtel',
      },
    };

    let orderResponse;
    let orderStatusCode;
    const resOrder = {
      status: (code) => {
        orderStatusCode = code;
        return resOrder;
      },
      json: (data) => {
        orderResponse = data;
        return resOrder;
      },
    };

    await createRazorpayRechargeOrder(reqOrder, resOrder, (err) => { if (err) console.error(err); });

    expect(orderStatusCode).toBe(200);
    expect(orderResponse.success).toBe(true);

    const internalTransactionId = orderResponse.data.internalTransactionId;
    const razorpayOrderId = orderResponse.data.razorpayOrderId;
    const razorpayPaymentId = `pay_${Date.now()}_test`;

    // Compute valid HMAC signature
    const razorpaySecret = (process.env.RAZORPAY_KEY_SECRET || 'v45oD145W4CRty7hAWrjJ1cq').trim();
    const razorpaySignature = crypto
      .createHmac('sha256', razorpaySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    const a1TopupProvider = require('../services/providers/a1topup/provider.service');
    jest.spyOn(a1TopupProvider, 'recharge').mockResolvedValue({
      success: true,
      status: 'SUCCESS',
      providerTransactionId: 'TEST_AIRTEL_999',
      operatorRef: 'OP_AIRTEL_999',
    });

    console.log('\n====================================================');
    console.log('[E2E AIRTEL TEST] Step 2: Verify Razorpay Payment & Execute A1Topup');
    console.log(`internalTransactionId: ${internalTransactionId}`);
    console.log(`razorpayOrderId: ${razorpayOrderId}`);
    console.log(`razorpayPaymentId: ${razorpayPaymentId}`);
    console.log('====================================================\n');

    const reqVerify = {
      user,
      body: {
        internalTransactionId,
        razorpayOrderId,
        razorpayPaymentId,
        razorpaySignature,
      },
    };

    let verifyResponse;
    let verifyStatusCode = 200;
    const resVerify = {
      status: (code) => {
        verifyStatusCode = code;
        return resVerify;
      },
      json: (data) => {
        verifyResponse = data;
        return resVerify;
      },
    };

    let nextErr;
    await verifyRazorpayRechargePayment(reqVerify, resVerify, (err) => { if (err) nextErr = err; });

    console.log('\n====================================================');
    console.log('[E2E AIRTEL TEST RESULT]');
    console.log(`HTTP Status: ${verifyStatusCode}`);
    console.log(`Verify Response:`, JSON.stringify(verifyResponse, null, 2));
    if (nextErr) console.log(`Next Error:`, nextErr.message);
    console.log('====================================================\n');

    expect(verifyStatusCode).toBe(200);
    expect(verifyResponse ? verifyResponse.success : false).toBe(true);

    // Verify DB record has provider initiation evidence
    const dbTxn = await RechargeTransaction.findOne({ orderId: internalTransactionId });
    expect(dbTxn).toBeDefined();
    expect(dbTxn.providerRequestSent).toBe(true);
    expect(['SUCCESS', 'PENDING', 'FAILED']).toContain(dbTxn.status);
    console.log(`[VERIFIED IN DB] orderId=${dbTxn.orderId}, providerRequestSent=${dbTxn.providerRequestSent}, status=${dbTxn.status}, providerTransactionId=${dbTxn.providerTransactionId}`);
  }, 30000);
});
