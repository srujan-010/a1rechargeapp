const mongoose = require('mongoose');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const Transaction = require('../models/Transaction');
const AdminAuditLog = require('../models/AdminAuditLog');
const walletService = require('../services/wallet/wallet.service');
const { creditRetailerWallet, searchRetailers, getAuditLogs } = require('../controllers/adminWalletController');
const { topupWallet, getBalance, getStatement, getDashboardSummary } = require('../controllers/walletController');
const path = require('path');
const connectDB = require('../config/db');

require('dotenv').config({ path: path.join(__dirname, '../.env') });

describe('Temporary Admin-Funded Wallet Mode Tests', () => {
  let adminUser;
  let retailerUser;
  let mockRes;
  let mockNext;

  beforeAll(async () => {
    await connectDB();
  });

  afterAll(async () => {
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    await User.deleteMany({ phone: { $in: ['9999000001', '9999000002'] } });
    await Wallet.deleteMany({});
    await WalletLedger.deleteMany({});
    await Transaction.deleteMany({});
    await AdminAuditLog.deleteMany({});

    adminUser = await User.create({
      name: 'System Admin',
      phone: '9999000001',
      retailerId: 'ADM000001',
      role: 'admin',
    });

    retailerUser = await User.create({
      name: 'Srujan',
      phone: '9999000002',
      retailerId: 'RET000001',
      role: 'retailer',
    });

    // Set initial balance of Srujan to ₹576.74 (57674 paise)
    await Wallet.create({
      userId: retailerUser._id,
      balancePaise: 57674,
      onHoldPaise: 0,
    });

    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    mockNext = jest.fn();
  });

  test('A. Admin credits ₹1,000 -> Retailer balance increases to ₹1,576.74', async () => {
    const req = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountRupees: 1000,
        remark: 'Initial operational wallet funding',
        referenceId: 'REF_TEST_1000',
      },
    };

    await creditRetailerWallet(req, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    const responseData = mockRes.json.mock.calls[0][0];
    expect(responseData.success).toBe(true);
    expect(responseData.data.previousBalanceRupees).toBe(576.74);
    expect(responseData.data.newBalanceRupees).toBe(1576.74);

    // Verify Wallet Balance in DB
    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(157674); // ₹1,576.74

    // Verify Ledger Entry
    const ledger = await WalletLedger.findOne({ referenceId: 'REF_TEST_1000' });
    expect(ledger).not.toBeNull();
    expect(ledger.referenceType).toBe('ADMIN_CREDIT');
    expect(ledger.amount).toBe(1000);
    expect(ledger.previousBalance).toBe(576.74);
    expect(ledger.balanceAfter).toBe(1576.74);
    expect(ledger.adminId.toString()).toBe(adminUser._id.toString());

    // Verify Transaction Record
    const tx = await Transaction.findOne({ referenceId: 'REF_TEST_1000' });
    expect(tx).not.toBeNull();
    expect(tx.service).toBe('admin_credit');
    expect(tx.amountPaise).toBe(100000);
    expect(tx.closingBalancePaise).toBe(157674);

    // Verify Audit Log Record
    const audit = await AdminAuditLog.findOne({ referenceId: 'REF_TEST_1000' });
    expect(audit).not.toBeNull();
    expect(audit.adminName).toBe('System Admin');
    expect(audit.retailerName).toBe('Srujan');
    expect(audit.amountRupees).toBe(1000);
  });

  test('B. Admin double-clicks credit -> Idempotency prevents duplicate funding', async () => {
    const req = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountRupees: 1000,
        remark: 'Initial operational wallet funding',
        referenceId: 'REF_IDEMPOTENT_TEST',
      },
    };

    // First Click
    await creditRetailerWallet(req, mockRes, mockNext);
    const walletAfterFirst = await Wallet.findOne({ userId: retailerUser._id });
    expect(walletAfterFirst.balancePaise).toBe(157674);

    // Second Click (Duplicate submission)
    const mockRes2 = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    await creditRetailerWallet(req, mockRes2, mockNext);

    expect(mockRes2.status).toHaveBeenCalledWith(200);
    const res2Data = mockRes2.json.mock.calls[0][0];
    expect(res2Data.success).toBe(true);
    expect(res2Data.data.isDuplicate).toBe(true);

    // Balance MUST still be ₹1,576.74 (NOT ₹2,576.74)
    const walletAfterSecond = await Wallet.findOne({ userId: retailerUser._id });
    expect(walletAfterSecond.balancePaise).toBe(157674);
  });

  test('C. Retailer tries payment gateway top-up -> Rejected with WALLET_FUNDING_DISABLED', async () => {
    process.env.WALLET_FUNDING_MODE = 'ADMIN_ONLY';

    const req = {
      user: retailerUser,
      body: { amountPaise: 100000 },
    };

    await topupWallet(req, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(400);
    const resData = mockRes.json.mock.calls[0][0];
    expect(resData.success).toBe(false);
    expect(resData.code).toBe('WALLET_FUNDING_DISABLED');
    expect(resData.message).toContain('Online wallet funding is currently unavailable');

    // Balance should remain unchanged
    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(57674);
  });

  test('D. Retailer performs recharge -> Wallet reserve, commit, release lifecycle works', async () => {
    // 1. Reserve ₹200 (20000 paise)
    const reserveSuccess = await walletService.reserveAmount(retailerUser._id, 200);
    expect(reserveSuccess).toBe(true);

    let wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(57674);
    expect(wallet.onHoldPaise).toBe(20000);

    // 2. Release reservation (simulating recharge failure)
    await walletService.releaseReservation(retailerUser._id, 200);
    wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.onHoldPaise).toBe(0);
    expect(wallet.balancePaise).toBe(57674);

    // 3. Reserve & Commit reservation (simulating recharge success)
    await walletService.reserveAmount(retailerUser._id, 200);
    await walletService.commitReservation(retailerUser._id, 200);
    wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.onHoldPaise).toBe(0);
    expect(wallet.balancePaise).toBe(37674); // ₹376.74
  });

  test('E. Statement page displays ADMIN CREDIT correctly', async () => {
    // Create an admin credit transaction
    await Transaction.create({
      userId: retailerUser._id,
      type: 'credit',
      amountPaise: 100000,
      status: 'success',
      service: 'admin_credit',
      referenceId: 'STMT_REF_123',
      description: 'Wallet credited by administrator',
      closingBalancePaise: 157674,
      completedAt: new Date(),
    });

    const req = {
      user: retailerUser,
      query: { page: 1, limit: 10 },
    };

    await getStatement(req, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    const data = mockRes.json.mock.calls[0][0].data;
    expect(data.length).toBe(1);
    expect(data[0].serviceType).toBe('admin_credit');
    expect(data[0].transactionTitle).toBe('ADMIN CREDIT');
    expect(data[0].customerIdentifier).toBe('Wallet credited by administrator');
  });

  test('F. Admin Wallet Credits are excluded from Today\'s Recharge Statistics', async () => {
    // Create an admin credit transaction
    await Transaction.create({
      userId: retailerUser._id,
      type: 'credit',
      amountPaise: 100000,
      status: 'success',
      service: 'admin_credit',
      referenceId: 'SUMMARY_REF_123',
      closingBalancePaise: 157674,
      createdAt: new Date(),
    });

    // Create an actual recharge transaction
    await Transaction.create({
      userId: retailerUser._id,
      type: 'debit',
      amountPaise: 29900, // ₹299.00
      status: 'success',
      service: 'mobile',
      mobileNumber: '9876543210',
      referenceId: 'RECHARGE_REF_123',
      closingBalancePaise: 127774,
      createdAt: new Date(),
    });

    const req = { user: retailerUser };
    await getDashboardSummary(req, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    const summary = mockRes.json.mock.calls[0][0].data;
    
    // Today's recharge should only be ₹299 (29900 paise), NOT including ₹1,000 admin credit!
    expect(summary.todayRechargeAmount).toBe(29900);
    expect(summary.todayTransactions).toBe(1);
  });
});
