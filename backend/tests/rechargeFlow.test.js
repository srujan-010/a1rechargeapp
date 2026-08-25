const mongoose = require('mongoose');
const { executeRecharge: processRecharge } = require('../controllers/recharge.controller');
const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');
const User = require('../models/User');
const { calculateCommission } = require('../utils/commissionEngine');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const connectDB = require('../config/db');

const a1TopupProvider = require('../services/providers/a1topup/provider.service');

jest.mock('../utils/commissionEngine', () => ({
  calculateCommission: jest.fn(),
}));

describe('Recharge Flow Atomicity Tests', () => {
  let mockReq;
  let mockRes;
  let mockNext;
  let mockUser;

  beforeAll(async () => {
    await connectDB();
  });

  afterAll(async () => {
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    const existingUser = await User.findOne({ phone: '9999999999' });
    if (existingUser) {
      await Wallet.deleteMany({ userId: existingUser._id });
      await Transaction.deleteMany({ userId: existingUser._id });
      await User.deleteOne({ _id: existingUser._id });
    }

    mockUser = await User.create({
      name: 'Test Retailer',
      phone: '9999999999',
      retailerId: 'RET123456',
      email: 'test@example.com',
      password: 'hashedPassword',
      mpin: '1234',
      role: 'retailer',
    });

    mockUser.matchMpin = jest.fn().mockResolvedValue(true);

    await Wallet.create({
      userId: mockUser._id,
      balancePaise: 50000, // 500 INR
    });

    mockReq = {
      user: mockUser,
      body: {
        mobileNumber: '9876543210',
        operatorId: 'airtel',
        operatorName: 'Airtel',
        serviceType: 'mobile',
        amount: 100,
        amountPaise: 10000, // 100 INR
        mpin: '1234',
        paymentMode: 'wallet',
      },
    };

    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    mockNext = jest.fn();
    calculateCommission.mockReturnValue({ commissionAmountPaise: 200, percentage: 2.0 });
  });

  it('should successfully process recharge, deduct wallet, credit commission, and create transactions', async () => {
    jest.spyOn(a1TopupProvider, 'recharge').mockResolvedValue({
      success: true,
      status: 'SUCCESS',
      providerTransactionId: 'TEST_A1_123',
      operatorRef: 'OP_REF_123',
    });

    await processRecharge(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    
    const wallet = await Wallet.findOne({ userId: mockUser._id });
    // Started with 50000 paise (500 INR), deducted 9960 paise (99.60 INR net payable) = 40040 paise
    expect(wallet.balancePaise).toBe(40040);

    const transactions = await Transaction.find({ userId: mockUser._id }).sort({ createdAt: 1 });
    expect(transactions.length).toBeGreaterThanOrEqual(1);

    expect(transactions[0].type).toBe('debit');
    expect(transactions[0].amountPaise).toBe(10000);
  });

  it('should completely rollback if any step fails (e.g. Transaction creation fails)', async () => {
    // Force a failure in the transaction creation by mocking it to throw
    const originalCreate = Transaction.create;
    Transaction.create = jest.fn().mockRejectedValue(new Error('Simulated DB Error'));

    await processRecharge(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(expect.any(Number));

    // Wallet balance should NOT have changed despite the code deducting it earlier
    const wallet = await Wallet.findOne({ userId: mockUser._id });
    expect(wallet.balancePaise).toBe(50000);

    // Restore original mock
    Transaction.create = originalCreate;
  });

  it('should reject if wallet balance is insufficient', async () => {
    mockReq.body.amount = 600;
    mockReq.body.amountPaise = 60000; // 600 INR, wallet only has 500

    await processRecharge(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(400);

    const wallet = await Wallet.findOne({ userId: mockUser._id });
    expect(wallet.balancePaise).toBe(50000);
  });
});
