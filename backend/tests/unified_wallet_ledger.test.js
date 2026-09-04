const mongoose = require('mongoose');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const Transaction = require('../models/Transaction');
const WalletFundingTransaction = require('../models/WalletFundingTransaction');
const AdminAuditLog = require('../models/AdminAuditLog');
const RechargeTransaction = require('../models/RechargeTransaction');
const walletService = require('../services/wallet/wallet.service');
const { creditRetailerWallet, debitRetailerWallet, getAuditLogs } = require('../controllers/adminWalletController');
const { verifyPayment, handleWebhook } = require('../controllers/razorpayWalletController');
const { getStatement } = require('../controllers/walletController');
const path = require('path');
const connectDB = require('../config/db');

require('dotenv').config({ path: path.join(__dirname, '../.env') });

describe('Unified Wallet History & Immutable Ledger Test Suite', () => {
  let adminUser;
  let retailerUser;

  const testPhoneAdmin = '9888111001';
  const testPhoneRetailer = '9888111002';

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
    await WalletFundingTransaction.deleteMany({});
    await AdminAuditLog.deleteMany({});
    await RechargeTransaction.deleteMany({});

    adminUser = await User.create({
      name: 'Test Admin',
      phone: testPhoneAdmin,
      retailerId: 'ADM_LEDGER_1',
      role: 'admin',
    });

    retailerUser = await User.create({
      name: 'Test Retailer',
      phone: testPhoneRetailer,
      retailerId: 'RET_LEDGER_1',
      role: 'retailer',
    });

    await Wallet.create({
      userId: retailerUser._id,
      balancePaise: 0,
      onHoldPaise: 0,
    });
  });

  // Test 1: UPI top-up creates exactly one wallet credit and one ledger record
  test('1. UPI top-up creates exactly one wallet credit and one ledger record', async () => {
    const internalTxId = `WFT_TEST_${Date.now()}`;
    const rzpOrderId = `order_test_${Date.now()}`;
    const rzpPayId = `pay_test_${Date.now()}`;

    const wft = await WalletFundingTransaction.create({
      internalTransactionId: internalTxId,
      userId: retailerUser._id,
      amountPaise: 50000, // ₹500.00
      amountRupees: 500,
      razorpayOrderId: rzpOrderId,
      status: 'PENDING',
      fundingMethod: 'RAZORPAY',
    });

    const mockReq = {
      user: retailerUser,
      body: {
        internalTransactionId: internalTxId,
        razorpayOrderId: rzpOrderId,
        razorpayPaymentId: rzpPayId,
        razorpaySignature: 'mock_valid_signature',
      },
    };

    let responseData = null;
    const mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockImplementation(data => { responseData = data; }),
    };
    const mockNext = jest.fn();

    await verifyPayment(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(responseData.success).toBe(true);

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(50000);

    const ledgers = await WalletLedger.find({ userId: retailerUser._id });
    expect(ledgers.length).toBe(1);
    expect(ledgers[0].transactionType).toBe('CREDIT');
    expect(ledgers[0].amountPaise).toBe(50000);
    expect(ledgers[0].previousBalancePaise).toBe(0);
    expect(ledgers[0].balanceAfterPaise).toBe(50000);
    expect(ledgers[0].referenceType).toBe('RAZORPAY_WALLET_CREDIT');
    expect(ledgers[0].referenceId).toBe(internalTxId);
  });

  // Test 2: Duplicate Razorpay callback does not create another credit
  test('2. Duplicate Razorpay callback does not create another credit', async () => {
    const internalTxId = `WFT_DUP_${Date.now()}`;
    const rzpOrderId = `order_dup_${Date.now()}`;
    const rzpPayId = `pay_dup_${Date.now()}`;

    await WalletFundingTransaction.create({
      internalTransactionId: internalTxId,
      userId: retailerUser._id,
      amountPaise: 30000,
      amountRupees: 300,
      razorpayOrderId: rzpOrderId,
      status: 'PENDING',
      fundingMethod: 'RAZORPAY',
    });

    const mockReq = {
      user: retailerUser,
      body: {
        internalTransactionId: internalTxId,
        razorpayOrderId: rzpOrderId,
        razorpayPaymentId: rzpPayId,
        razorpaySignature: 'mock_valid_signature',
      },
    };

    const mockRes = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    const mockNext = jest.fn();

    // First call
    await verifyPayment(mockReq, mockRes, mockNext);

    // Second call (Duplicate)
    let dupResponse = null;
    const mockResDup = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockImplementation(data => { dupResponse = data; }),
    };

    await verifyPayment(mockReq, mockResDup, mockNext);

    expect(mockResDup.status).toHaveBeenCalledWith(200);
    expect(dupResponse.isDuplicate).toBe(true);

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(30000); // Balance untouched on retry

    const ledgers = await WalletLedger.find({ userId: retailerUser._id });
    expect(ledgers.length).toBe(1); // Still exactly one ledger entry
  });

  // Test 3: Admin credit creates exactly one ledger record
  test('3. Admin credit creates exactly one ledger record', async () => {
    const refId = `ADM_REF_${Date.now()}`;

    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 25000, // ₹250.00
        remark: 'Test Manual Credit',
        referenceId: refId,
      },
    };

    let responseData = null;
    const mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockImplementation(data => { responseData = data; }),
    };
    const mockNext = jest.fn();

    await creditRetailerWallet(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(responseData.success).toBe(true);

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(25000);

    const ledgers = await WalletLedger.find({ userId: retailerUser._id, referenceType: 'ADMIN_CREDIT' });
    expect(ledgers.length).toBe(1);
    expect(ledgers[0].amountPaise).toBe(25000);
    expect(ledgers[0].previousBalancePaise).toBe(0);
    expect(ledgers[0].balanceAfterPaise).toBe(25000);
    expect(ledgers[0].referenceId).toBe(refId);
  });

  // Test 4: Duplicate admin request cannot double-credit
  test('4. Duplicate admin request cannot double-credit', async () => {
    const refId = `ADM_IDEM_${Date.now()}`;

    const mockReq = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 10000,
        remark: 'Idempotency test credit',
        referenceId: refId,
      },
    };

    const mockRes1 = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    const mockNext = jest.fn();

    // First request
    await creditRetailerWallet(mockReq, mockRes1, mockNext);

    // Second request with same referenceId
    let dupResponse = null;
    const mockRes2 = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockImplementation(data => { dupResponse = data; }),
    };

    await creditRetailerWallet(mockReq, mockRes2, mockNext);

    expect(mockRes2.status).toHaveBeenCalledWith(200);
    expect(dupResponse.data.isDuplicate).toBe(true);

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(10000); // Balance credited only once

    const ledgers = await WalletLedger.find({ userId: retailerUser._id });
    expect(ledgers.length).toBe(1);
  });

  // Test 5: Wallet balance and ledger reconcile
  test('5. Wallet balance and ledger reconcile', async () => {
    // 1. Initial credit via addBalance
    await walletService.addBalance(retailerUser._id, 100, {
      referenceType: 'ADD_MONEY',
      referenceId: 'REF_REC_1',
      description: 'Initial Topup',
    });

    // 2. Admin credit
    const mockReqAdmin = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 5000, // ₹50.00
        remark: 'Bonus Credit',
        referenceId: 'REF_REC_2',
      },
    };
    await creditRetailerWallet(mockReqAdmin, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    // 3. Admin debit
    const mockReqDebit = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 2000, // ₹20.00
        remark: 'Adjustment Debit',
        referenceId: 'REF_REC_3',
      },
    };
    await debitRetailerWallet(mockReqDebit, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    const allLedgers = await WalletLedger.find({ userId: retailerUser._id });

    let calculatedBalancePaise = 0;
    for (const entry of allLedgers) {
      if (entry.transactionType === 'CREDIT') {
        calculatedBalancePaise += entry.amountPaise;
      } else if (entry.transactionType === 'DEBIT') {
        calculatedBalancePaise -= entry.amountPaise;
      }
    }

    expect(wallet.balancePaise).toBe(13000); // 10000 + 5000 - 2000 = 13000
    expect(calculatedBalancePaise).toBe(wallet.balancePaise);
  });

  // Test 6: Retailer history displays the credit
  test('6. Retailer history displays the credit', async () => {
    await walletService.addBalance(retailerUser._id, 200, {
      referenceType: 'ADD_MONEY',
      referenceId: 'STAT_REF_1',
      description: 'UPI Credit Stat Test',
    });

    const mockReq = {
      user: retailerUser,
      query: { page: 1, limit: 20 },
    };

    let responseData = null;
    const mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockImplementation(data => { responseData = data; }),
    };
    const mockNext = jest.fn();

    await getStatement(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(responseData.success).toBe(true);
    expect(responseData.data.length).toBeGreaterThanOrEqual(1);

    const match = responseData.data.find(item => item.referenceNumber === 'STAT_REF_1');
    expect(match).toBeDefined();
    expect(match.amount).toBe(20000);
    expect(match.type).toBe('credit');
  });

  // Test 7: Admin history displays the same credit
  test('7. Admin history displays the same credit', async () => {
    const refId = `ADM_HIST_${Date.now()}`;

    const mockReqCredit = {
      user: adminUser,
      body: {
        retailerUserId: retailerUser._id.toString(),
        amountPaise: 15000,
        remark: 'Admin History Test Credit',
        referenceId: refId,
      },
    };
    await creditRetailerWallet(mockReqCredit, { status: jest.fn().mockReturnThis(), json: jest.fn() }, jest.fn());

    const mockReqAudit = { query: { page: 1, limit: 20 } };
    let auditData = null;
    const mockResAudit = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockImplementation(data => { auditData = data; }),
    };

    await getAuditLogs(mockReqAudit, mockResAudit, jest.fn());

    expect(mockResAudit.status).toHaveBeenCalledWith(200);
    const auditRecord = auditData.data.find(a => a.referenceId === refId);
    expect(auditRecord).toBeDefined();
    expect(auditRecord.amountRupees).toBe(150);

    const ledgerRecord = await WalletLedger.findOne({ referenceId: refId });
    expect(ledgerRecord).toBeDefined();
    expect(ledgerRecord.amountPaise).toBe(15000);
  });

  // Test 8: Recharge debit remains separate from wallet top-up credit
  test('8. Recharge debit remains separate from wallet top-up credit', async () => {
    await Wallet.updateOne({ userId: retailerUser._id }, { balancePaise: 50000 });

    const orderId = `ORD_RCH_${Date.now()}`;
    const rechargeTxn = await RechargeTransaction.create({
      orderId,
      userId: retailerUser._id,
      mobileNumber: '9999999999',
      amount: 100,
      grossAmountPaise: 10000,
      commissionAmountPaise: 200,
      netPayablePaise: 9800,
      operatorCode: 'AIRTEL',
      circleCode: 'AP',
      status: 'INITIATED',
      paymentMethod: 'WALLET',
    });

    await walletService.reserveWalletAmount({
      userId: retailerUser._id,
      netPayablePaise: 9800,
      orderId,
      paymentMethod: 'WALLET',
    });

    await walletService.settleWalletOrder({
      userId: retailerUser._id,
      orderId,
      netPayablePaise: 9800,
    });

    const debitLedger = await WalletLedger.findOne({ referenceId: rechargeTxn._id, transactionType: 'DEBIT' });
    expect(debitLedger).toBeDefined();
    expect(debitLedger.amountPaise).toBe(9800);
    expect(debitLedger.referenceType).toBe('RECHARGE');

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(wallet.balancePaise).toBe(40200); // 50000 - 9800
  });

  // Test 9: Failed recharge does not create a permanent debit
  test('9. Failed recharge does not create a permanent debit', async () => {
    await Wallet.updateOne({ userId: retailerUser._id }, { balancePaise: 20000, onHoldPaise: 0 });

    const orderId = `ORD_FAIL_${Date.now()}`;
    await RechargeTransaction.create({
      orderId,
      userId: retailerUser._id,
      mobileNumber: '8888888888',
      amount: 50,
      grossAmountPaise: 5000,
      netPayablePaise: 4900,
      operatorCode: 'VI',
      circleCode: 'AP',
      status: 'INITIATED',
      paymentMethod: 'WALLET',
    });

    await walletService.reserveWalletAmount({
      userId: retailerUser._id,
      netPayablePaise: 4900,
      orderId,
      paymentMethod: 'WALLET',
    });

    const walletHeld = await Wallet.findOne({ userId: retailerUser._id });
    expect(walletHeld.onHoldPaise).toBe(4900);
    expect(walletHeld.balancePaise).toBe(20000); // Balance untouched during hold

    await walletService.releaseOrderHold({
      userId: retailerUser._id,
      orderId,
      netPayablePaise: 4900,
    });

    const walletReleased = await Wallet.findOne({ userId: retailerUser._id });
    expect(walletReleased.onHoldPaise).toBe(0);
    expect(walletReleased.balancePaise).toBe(20000); // Balance remains untouched!

    const debitLedgers = await WalletLedger.find({ userId: retailerUser._id, referenceType: 'RECHARGE' });
    expect(debitLedgers.length).toBe(0); // Zero debit ledger created!
  });

  // Test 10: All money calculations are integer paise
  test('10. All money calculations are integer paise', async () => {
    await walletService.addBalance(retailerUser._id, 123.456, {
      referenceType: 'ADD_MONEY',
      referenceId: 'PAISE_INT_1',
      description: 'Decimal rounding test',
    });

    const wallet = await Wallet.findOne({ userId: retailerUser._id });
    expect(Number.isInteger(wallet.balancePaise)).toBe(true);
    expect(wallet.balancePaise).toBe(12346); // Math.round(123.456 * 100)

    const ledger = await WalletLedger.findOne({ referenceId: 'PAISE_INT_1' });
    expect(Number.isInteger(ledger.amountPaise)).toBe(true);
    expect(Number.isInteger(ledger.previousBalancePaise)).toBe(true);
    expect(Number.isInteger(ledger.balanceAfterPaise)).toBe(true);
    expect(ledger.amountPaise).toBe(12346);
  });
});
