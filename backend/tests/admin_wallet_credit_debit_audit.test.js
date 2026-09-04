const mongoose = require('mongoose');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const Transaction = require('../models/Transaction');
const AdminAuditLog = require('../models/AdminAuditLog');
const walletService = require('../services/wallet/wallet.service');
const { creditRetailerWallet, debitRetailerWallet, getAuditLogs } = require('../controllers/adminWalletController');
const { getStatement } = require('../controllers/walletController');
const path = require('path');
const connectDB = require('../config/db');

require('dotenv').config({ path: path.join(__dirname, '../.env') });

describe('Admin Wallet Adjustment Audit & Retention Test Suite', () => {
  let adminUser;
  let retailerUser;

  const testPhoneAdmin = '9777111001';
  const testPhoneRetailer = '9777111002';

  beforeAll(async () => {
    await connectDB();
  });

  afterAll(async () => {
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    await User.deleteMany({ phone: { $in: [testPhoneAdmin, testPhoneRetailer] } });
    await Wallet.deleteMany({});
    await WalletLedger.deleteMany({});
    await Transaction.deleteMany({});
    await AdminAuditLog.deleteMany({});

    adminUser = await User.create({
      name: 'Super Admin Officer',
      phone: testPhoneAdmin,
      retailerId: 'ADM_AUDIT_1',
      role: 'admin',
    });

    retailerUser = await User.create({
      name: 'Kamal Retailer',
      phone: testPhoneRetailer,
      retailerId: 'RET_AUDIT_1',
      role: 'retailer',
    });

    await Wallet.create({
      userId: retailerUser._id,
      balancePaise: 50000, // Initial ₹500.00
      onHoldPaise: 0,
    });
  });

  // TEST 1: Admin Credit ₹100 -> ADMIN_CREDIT, CREDIT, +₹100, reason persisted, admin identity persisted
  test('TEST 1: Admin Credit ₹100 -> ADMIN_CREDIT, CREDIT, +₹100, reason & admin identity persisted', async () => {
    const refId = `ADM_CRED_100_${Date.now()}`;
    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 10000, // ₹100.00
        remark: 'Customer offline payment received',
        referenceId: refId,
      },
    };

    let responseData = null;
    const mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockImplementation(data => { responseData = data; }),
    };

    await creditRetailerWallet(mockReq, mockRes, jest.fn());

    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(responseData.success).toBe(true);

    const txn = await Transaction.findOne({ referenceId: refId });
    expect(txn).toBeDefined();
    expect(txn.service).toBe('admin_credit');
    expect(txn.type).toBe('credit');
    expect(txn.amountPaise).toBe(10000);
    expect(txn.paymentMethod).toBe('ADMIN');
    expect(txn.operatorName).toBe('Admin');
    expect(txn.adminName).toBe('Super Admin Officer');
    expect(txn.reason).toBe('Customer offline payment received');

    const ledger = await WalletLedger.findOne({ referenceId: refId });
    expect(ledger).toBeDefined();
    expect(ledger.transactionType).toBe('CREDIT');
    expect(ledger.referenceType).toBe('ADMIN_CREDIT');
    expect(ledger.amountPaise).toBe(10000);
    expect(ledger.previousBalancePaise).toBe(50000);
    expect(ledger.balanceAfterPaise).toBe(60000);
  });

  // TEST 2: Admin Debit ₹100 -> ADMIN_DEBIT, DEBIT, -₹100, reason & admin identity persisted
  test('TEST 2: Admin Debit ₹100 -> ADMIN_DEBIT, DEBIT, -₹100, reason & admin identity persisted', async () => {
    const refId = `ADM_DEB_100_${Date.now()}`;
    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 10000, // ₹100.00
        remark: 'Wallet correction for duplicate credit',
        referenceId: refId,
      },
    };

    let responseData = null;
    const mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockImplementation(data => { responseData = data; }),
    };

    await debitRetailerWallet(mockReq, mockRes, jest.fn());

    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(responseData.success).toBe(true);

    const txn = await Transaction.findOne({ referenceId: refId });
    expect(txn).toBeDefined();
    expect(txn.service).toBe('admin_debit');
    expect(txn.type).toBe('debit');
    expect(txn.amountPaise).toBe(10000);
    expect(txn.paymentMethod).toBe('ADMIN');
    expect(txn.operatorName).toBe('Admin');
    expect(txn.adminName).toBe('Super Admin Officer');
    expect(txn.reason).toBe('Wallet correction for duplicate credit');

    const ledger = await WalletLedger.findOne({ referenceId: refId });
    expect(ledger).toBeDefined();
    expect(ledger.transactionType).toBe('DEBIT');
    expect(ledger.referenceType).toBe('ADMIN_DEBIT');
    expect(ledger.amountPaise).toBe(10000);
    expect(ledger.previousBalancePaise).toBe(50000);
    expect(ledger.balanceAfterPaise).toBe(40000);
  });

  // TEST 3: Admin Debit must NEVER become ADMIN_CREDIT
  test('TEST 3: Admin Debit must NEVER become ADMIN_CREDIT', async () => {
    const refId = `ADM_DEB_NEVER_${Date.now()}`;
    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 7645, // ₹76.45
        remark: 'Correction debit ₹76.45',
        referenceId: refId,
      },
    };

    await debitRetailerWallet(mockReq, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    const txn = await Transaction.findOne({ referenceId: refId });
    expect(txn.service).not.toBe('admin_credit');
    expect(txn.service).toBe('admin_debit');
    expect(txn.type).toBe('debit');

    // Test Statement API
    let statementResponse = null;
    const mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockImplementation(data => { statementResponse = data; }),
    };

    await getStatement({ user: retailerUser, query: { page: 1, limit: 20 } }, mockRes, jest.fn());

    const item = statementResponse.data.find(i => i.referenceNumber === refId);
    expect(item).toBeDefined();
    expect(item.serviceType).toBe('admin_debit');
    expect(item.transactionTitle).toBe('ADMIN DEBIT');
    expect(item.type).toBe('debit');
    expect(item.operatorName).toBe('Admin');
    expect(item.paymentMethod).toBe('ADMIN');
  });

  // TEST 4: Admin Credit must NEVER become ADMIN_DEBIT
  test('TEST 4: Admin Credit must NEVER become ADMIN_DEBIT', async () => {
    const refId = `ADM_CRED_NEVER_${Date.now()}`;
    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 5000,
        remark: 'Bonus Credit',
        referenceId: refId,
      },
    };

    await creditRetailerWallet(mockReq, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    const txn = await Transaction.findOne({ referenceId: refId });
    expect(txn.service).not.toBe('admin_debit');
    expect(txn.service).toBe('admin_credit');
    expect(txn.type).toBe('credit');
  });

  // TEST 5: Reason entered in Admin Portal appears in database, admin history, and retailer history
  test('TEST 5: Reason entered in Admin Portal appears across all APIs', async () => {
    const refId = `ADM_REASON_${Date.now()}`;
    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 1500,
        remark: 'Special promotional adjustment for retail store',
        referenceId: refId,
      },
    };

    await creditRetailerWallet(mockReq, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    // Check DB
    const txn = await Transaction.findOne({ referenceId: refId });
    expect(txn.reason).toBe('Special promotional adjustment for retail store');

    // Check Admin Audit Logs API
    let auditData = null;
    await getAuditLogs({ query: { page: 1, limit: 20 } }, { status: jest.fn().mockReturnThis(), json: data => { auditData = data; } }, jest.fn());
    const auditRecord = auditData.data.find(a => a.referenceId === refId);
    expect(auditRecord.remark).toBe('Special promotional adjustment for retail store');

    // Check Retailer Statement API
    let statementData = null;
    await getStatement({ user: retailerUser, query: { page: 1, limit: 20 } }, { status: jest.fn().mockReturnThis(), json: data => { statementData = data; } }, jest.fn());
    const statementRecord = statementData.data.find(s => s.referenceNumber === refId);
    expect(statementRecord.reason).toBe('Special promotional adjustment for retail store');
  });

  // TEST 6: Authenticated admin identity appears in audit/history
  test('TEST 6: Authenticated admin identity appears in audit/history', async () => {
    const refId = `ADM_ID_${Date.now()}`;
    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 8000,
        remark: 'Test Admin Identity Retention',
        referenceId: refId,
      },
    };

    await creditRetailerWallet(mockReq, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    const txn = await Transaction.findOne({ referenceId: refId });
    expect(txn.adminId.toString()).toBe(adminUser._id.toString());
    expect(txn.adminName).toBe('Super Admin Officer');

    let auditData = null;
    await getAuditLogs({ query: { page: 1, limit: 20 } }, { status: jest.fn().mockReturnThis(), json: data => { auditData = data; } }, jest.fn());
    const auditRecord = auditData.data.find(a => a.referenceId === refId);
    expect(auditRecord.adminName).toBe('Super Admin Officer');
  });

  // TEST 7: Wallet balance before/after reconciles exactly
  test('TEST 7: Wallet balance before/after reconciles exactly', async () => {
    const refId = `ADM_RECON_${Date.now()}`;

    // Balance starts at 50000 (₹500.00)
    const mockReqDebit = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 7645, // ₹76.45
        remark: 'Debit 76.45',
        referenceId: refId,
      },
    };

    await debitRetailerWallet(mockReqDebit, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    const audit = await AdminAuditLog.findOne({ referenceId: refId });
    expect(audit.previousBalancePaise).toBe(50000);
    expect(audit.newBalancePaise).toBe(42355);
    expect(audit.amountPaise).toBe(7645);
    expect(audit.previousBalanceRupees).toBe(500);
    expect(audit.newBalanceRupees).toBe(423.55);

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(42355);
  });

  // TEST 8: Duplicate request does not double-adjust wallet
  test('TEST 8: Duplicate request does not double-adjust wallet', async () => {
    const refId = `ADM_DUP_${Date.now()}`;
    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 5000,
        remark: 'Duplicate test',
        referenceId: refId,
      },
    };

    await creditRetailerWallet(mockReq, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    let dupRes = null;
    await creditRetailerWallet(mockReq, { status: jest.fn().mockReturnThis(), json: data => { dupRes = data; } }, jest.fn());

    expect(dupRes.data.isDuplicate).toBe(true);

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(55000); // Only 5000 added once (50000 + 5000)
  });

  // TEST 9: Wallet update and ledger creation are atomic
  test('TEST 9: Wallet update and ledger creation are atomic', async () => {
    const refId = `ADM_ATOMIC_${Date.now()}`;
    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 4000,
        remark: 'Atomic check',
        referenceId: refId,
      },
    };

    await creditRetailerWallet(mockReq, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    const ledger = await WalletLedger.findOne({ referenceId: refId });
    const txn = await Transaction.findOne({ referenceId: refId });

    expect(wallet).toBeDefined();
    expect(ledger).toBeDefined();
    expect(txn).toBeDefined();
    expect(wallet.balancePaise).toBe(ledger.balanceAfterPaise);
    expect(wallet.balancePaise).toBe(txn.closingBalancePaise);
  });

  // TEST 10: All amounts use integer paise
  test('TEST 10: All amounts use integer paise', async () => {
    const refId = `ADM_INT_PAISE_${Date.now()}`;
    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 12345,
        remark: 'Paise precision test',
        referenceId: refId,
      },
    };

    await creditRetailerWallet(mockReq, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    const ledger = await WalletLedger.findOne({ referenceId: refId });
    const txn = await Transaction.findOne({ referenceId: refId });

    expect(Number.isInteger(ledger.amountPaise)).toBe(true);
    expect(Number.isInteger(ledger.previousBalancePaise)).toBe(true);
    expect(Number.isInteger(ledger.balanceAfterPaise)).toBe(true);
    expect(Number.isInteger(txn.amountPaise)).toBe(true);
    expect(Number.isInteger(txn.closingBalancePaise)).toBe(true);
  });
});
