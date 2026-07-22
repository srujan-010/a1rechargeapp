const mongoose = require('mongoose');
const { processRecharge } = require('../controllers/serviceController');
const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');
const User = require('../models/User');
const { calculateCommission } = require('../utils/commissionEngine');
require('dotenv').config({ path: '../.env' });
const connectDB = require('../config/db');

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
    // Note: Removed dropDatabase() to prevent wiping the main DB if testing against it
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    await Wallet.deleteMany({});
    await Transaction.deleteMany({});
    await User.deleteMany({});

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
    await processRecharge(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    
    const wallet = await Wallet.findOne({ userId: mockUser._id });
    // Started with 50000, deducted 10000, added 200 commission = 40200
    expect(wallet.balancePaise).toBe(40200);

    const transactions = await Transaction.find({ userId: mockUser._id }).sort({ createdAt: 1 });
    expect(transactions.length).toBe(2);

    expect(transactions[0].type).toBe('debit');
    expect(transactions[0].amountPaise).toBe(10000);
    expect(transactions[0].service).toBe('mobile');

    expect(transactions[1].type).toBe('credit');
    expect(transactions[1].amountPaise).toBe(200);
    expect(transactions[1].service).toBe('commission');
  });

  it('should completely rollback if any step fails (e.g. Transaction creation fails)', async () => {
    // Force a failure in the transaction creation by mocking it to throw
    const originalCreate = Transaction.create;
    Transaction.create = jest.fn().mockRejectedValue(new Error('Simulated DB Error'));

    await processRecharge(mockReq, mockRes, mockNext);

    // Should call next with the error
    expect(mockNext).toHaveBeenCalled();
    expect(mockNext.mock.calls[0][0].message).toBe('Simulated DB Error');

    // Wallet balance should NOT have changed despite the code deducting it earlier
    const wallet = await Wallet.findOne({ userId: mockUser._id });
    expect(wallet.balancePaise).toBe(50000);

    // No transactions should exist
    const transactions = await Transaction.find({ userId: mockUser._id });
    expect(transactions.length).toBe(0);

    // Restore original mock
    Transaction.create = originalCreate;
  });

  it('should reject if wallet balance is insufficient', async () => {
    mockReq.body.amountPaise = 60000; // 600 INR, wallet only has 500

    await processRecharge(mockReq, mockRes, mockNext);

    expect(mockNext).toHaveBeenCalled();
    expect(mockNext.mock.calls[0][0].message).toBe('Insufficient balance in wallet');

    const wallet = await Wallet.findOne({ userId: mockUser._id });
    expect(wallet.balancePaise).toBe(50000);
  });
});
