const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const ProviderOperator = require('../models/ProviderOperator');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');
const { executeRecharge, createRazorpayRechargeOrder } = require('../controllers/recharge.controller');

describe('Razorpay vs Wallet Payment Architecture Validation', () => {
  let user;
  let wallet;
  let operator;

  beforeAll(async () => {
    jest.spyOn(a1TopupProvider, 'recharge').mockResolvedValue({
      status: 'SUCCESS',
      providerTransactionId: 'TEST_A1_TXN_999',
      operatorReference: 'OP_REF_999',
      message: 'Test recharge success',
    });
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test');
    }

    const salt = await bcrypt.genSalt(10);
    const mpinHash = await bcrypt.hash('123456', salt);

    user = await User.create({
      name: 'Zero Balance Retailer',
      phone: '9998887776',
      retailerId: 'RET999888',
      email: 'zerobalance@test.com',
      mpinHash,
    });

    // Create wallet with EXACTLY ₹0 balance
    wallet = await Wallet.create({
      userId: user._id,
      balancePaise: 0,
    });

    operator = await ProviderOperator.findOne({ code: 'BT', provider: 'A1Topup' });
    if (!operator) {
      operator = await ProviderOperator.create({
        name: 'BSNL TOPUP',
        code: 'BT',
        category: 'Mobile',
        serviceType: 'Mobile',
        provider: 'A1Topup',
        status: true,
      });
    }
  });

  afterAll(async () => {
    if (user) await User.deleteOne({ _id: user._id });
    if (wallet) await Wallet.deleteOne({ userId: user._id });
    await RechargeTransaction.deleteMany({ userId: user._id });
    await Transaction.deleteMany({ userId: user._id });
    await mongoose.connection.close();
  });

  test('1. Razorpay order creation works with ₹0 wallet balance and uses payable amount', async () => {
    const req = {
      user,
      body: {
        mobileNumber: '9421729714',
        amount: 10,
        operatorId: operator._id.toString(),
        serviceType: 'mobile',
        operatorName: 'BSNL TOPUP',
      },
    };

    let responseData;
    let statusCode;
    const res = {
      status: (code) => {
        statusCode = code;
        return res;
      },
      json: (data) => {
        responseData = data;
        return res;
      },
    };

    await createRazorpayRechargeOrder(req, res, () => {});

    expect(statusCode).toBe(200);
    expect(responseData.success).toBe(true);
    expect(responseData.data.rechargeAmount).toBe(10);
    expect(responseData.data.payableAmount).toBeLessThanOrEqual(10); // Commission preview
    expect(responseData.data.razorpayOrderId).toBeDefined();

    // Verify database transaction record
    const txn = await RechargeTransaction.findOne({ orderId: responseData.data.internalTransactionId });
    expect(txn).toBeDefined();
    expect(txn.status).toBe('PAYMENT_PENDING');
    expect(txn.paymentMethod).toBe('RAZORPAY_UPI');
  });

  test('2. Wallet payment fails with "Insufficient wallet balance" when wallet has ₹0', async () => {
    const req = {
      user,
      body: {
        mobileNumber: '9421729714',
        amount: 10,
        operatorId: operator._id.toString(),
        serviceType: 'mobile',
        paymentMode: 'wallet',
        mpin: '123456',
      },
    };

    let responseData;
    let statusCode;
    const res = {
      status: (code) => {
        statusCode = code;
        return res;
      },
      json: (data) => {
        responseData = data;
        return res;
      },
    };

    await executeRecharge(req, res, () => {});

    expect(statusCode).toBe(400);
    expect(responseData.success).toBe(false);
    expect(responseData.message).toContain('balance');
  });

  test('3. Razorpay payment mode in executeRecharge skips wallet reservation', async () => {
    const req = {
      user,
      body: {
        mobileNumber: '9421729714',
        amount: 10,
        operatorId: operator._id.toString(),
        serviceType: 'mobile',
        paymentMode: 'RAZORPAY', // Non-wallet payment mode
      },
    };

    let responseData;
    let statusCode;
    const res = {
      status: (code) => {
        statusCode = code;
        return res;
      },
      json: (data) => {
        responseData = data;
        return res;
      },
    };

    await executeRecharge(req, res, () => {});

    // Should NOT throw "Insufficient wallet balance"
    expect(responseData.message || '').not.toContain('balance');
  });
});
