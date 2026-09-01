const mongoose = require('mongoose');
const OperatorCommission = require('../models/OperatorCommission');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const RechargeTransaction = require('../models/RechargeTransaction');
const CommissionHistory = require('../models/CommissionHistory');
const commissionService = require('../services/commission/commission.service');
const walletService = require('../services/wallet/wallet.service');

const TEST_DB_URI = 'mongodb://localhost:27017/a1recharge_test?retryWrites=false';

describe('Financial Accounting & Commission Engine Audit Test Suite', () => {
  let testUser;

  beforeAll(async () => {
    // Assert strictly local test database
    if (!TEST_DB_URI.includes('localhost') && !TEST_DB_URI.includes('127.0.0.1')) {
      throw new Error('[FATAL SECURITY VIOLATION] Tests must run ONLY against local test database.');
    }
    await mongoose.connect(TEST_DB_URI);
  });

  afterAll(async () => {
    await mongoose.disconnect();
  });

  beforeEach(async () => {
    // Clear test collections
    await OperatorCommission.deleteMany({});
    await User.deleteMany({});
    await Wallet.deleteMany({});
    await WalletLedger.deleteMany({});
    await RechargeTransaction.deleteMany({});
    await CommissionHistory.deleteMany({});

    // Seed test user
    testUser = await User.create({
      name: 'Test Retailer',
      phone: '9999988888',
      role: 'retailer',
      retailerId: 'RET99999',
      accountType: 'BUSINESS',
    });

    // Seed test wallet with ₹1000 (100000 paise)
    await Wallet.create({
      userId: testUser._id,
      balancePaise: 100000,
      onHoldPaise: 0,
      currency: 'INR',
    });

    // Seed active operator commission slabs in MongoDB
    await OperatorCommission.create([
      {
        accountType: 'BUSINESS',
        operatorCode: 'AT',
        operatorName: 'Airtel',
        serviceType: 'mobile',
        commissionType: 'percentage',
        providerCommission: 2.0,
        retailerCommission: 1.0,
        companyCommission: 1.0,
        status: 'ACTIVE',
      },
      {
        accountType: 'BUSINESS',
        operatorCode: 'BSNL',
        operatorName: 'BSNL',
        serviceType: 'mobile',
        commissionType: 'percentage',
        providerCommission: 3.0,
        retailerCommission: 2.0,
        companyCommission: 1.0,
        status: 'ACTIVE',
      },
      {
        accountType: 'PERSONAL',
        operatorCode: 'AT',
        operatorName: 'Airtel',
        serviceType: 'mobile',
        commissionType: 'percentage',
        providerCommission: 2.0,
        retailerCommission: 0.4,
        personalCommission: 0.4,
        companyCommission: 1.6,
        status: 'ACTIVE',
      },
    ]);
  });

  // TEST 1: WALLET SUCCESS & INVARIANTS
  it('TEST 1: WALLET SUCCESS — calculates commission from database slab and debits net payable exactly once', async () => {
    const grossPaise = 29500; // ₹295
    const orderId = `A1TEST_${Date.now()}`;

    // 1. Commission Calculation
    const commResult = await commissionService.calculateCommission('AT', 295, 'Airtel', 'mobile', {
      orderId,
      retailerId: String(testUser._id),
      accountType: 'BUSINESS',
    });

    expect(commResult.grossAmountPaise).toBe(29500);
    expect(commResult.retailerCommissionPercentage).toBe(1.0);
    expect(commResult.retailerCommissionAmountPaise).toBe(295); // 1.0% of 29500 = 295
    expect(commResult.netPayablePaise).toBe(29205); // 29500 - 295 = 29205

    // Accounting invariant check
    expect(commResult.grossAmountPaise).toBe(commResult.retailerCommissionAmountPaise + commResult.netPayablePaise);

    // Create RechargeTransaction
    const txn = await RechargeTransaction.create({
      orderId,
      userId: testUser._id,
      mobileNumber: '9999988888',
      operatorCode: 'AT',
      circleCode: '1',
      grossAmountPaise: 29500,
      commissionAmountPaise: 295,
      netPayablePaise: 29205,
      amount: 295,
      commissionAmount: 2.95,
      payableAmount: 292.05,
      status: 'PENDING',
      paymentMethod: 'WALLET',
      walletSettlementStatus: 'PENDING',
    });

    // 2. Reserve Hold
    await walletService.reserveWalletAmount({
      userId: testUser._id,
      netPayablePaise: 29205,
      orderId,
      paymentMethod: 'WALLET',
    });

    let walletState = await Wallet.findOne({ userId: testUser._id });
    expect(walletState.balancePaise).toBe(100000);
    expect(walletState.onHoldPaise).toBe(29205);

    // 3. Settle Wallet Order
    const settleResult = await walletService.settleWalletOrder({
      userId: testUser._id,
      orderId,
      netPayablePaise: 29205,
    });

    expect(settleResult.success).toBe(true);
    expect(settleResult.alreadySettled).toBe(false);

    walletState = await Wallet.findOne({ userId: testUser._id });
    expect(walletState.balancePaise).toBe(70795); // 100000 - 29205 = 70795
    expect(walletState.onHoldPaise).toBe(0);

    const ledgers = await WalletLedger.find({ userId: testUser._id });
    expect(ledgers.length).toBe(1);
    expect(ledgers[0].amountPaise).toBe(29205);
    expect(ledgers[0].transactionType).toBe('DEBIT');
  });

  // TEST 2: IDEMPOTENT DUPLICATE CALLBACK
  it('TEST 2: WALLET DUPLICATE CALLBACK — duplicate settlement call results in zero second debit', async () => {
    const orderId = `A1TEST_DUP_${Date.now()}`;

    await RechargeTransaction.create({
      orderId,
      userId: testUser._id,
      mobileNumber: '9999988888',
      operatorCode: 'AT',
      circleCode: '1',
      grossAmountPaise: 10000,
      commissionAmountPaise: 100,
      netPayablePaise: 9900,
      amount: 100,
      payableAmount: 99,
      status: 'PENDING',
      paymentMethod: 'WALLET',
      walletSettlementStatus: 'PENDING',
    });

    await walletService.reserveWalletAmount({ userId: testUser._id, netPayablePaise: 9900, orderId, paymentMethod: 'WALLET' });
    await walletService.settleWalletOrder({ userId: testUser._id, orderId, netPayablePaise: 9900 });

    // Call settlement second time
    const duplicateResult = await walletService.settleWalletOrder({ userId: testUser._id, orderId, netPayablePaise: 9900 });
    expect(duplicateResult.success).toBe(true);
    expect(duplicateResult.alreadySettled).toBe(true);

    const walletState = await Wallet.findOne({ userId: testUser._id });
    expect(walletState.balancePaise).toBe(90100); // 100000 - 9900 = 90100 (exactly one debit)

    const ledgers = await WalletLedger.find({ userId: testUser._id });
    expect(ledgers.length).toBe(1);
  });

  // TEST 3: WALLET FAILURE & HOLD RELEASE
  it('TEST 3: WALLET FAILURE — releases hold and produces permanent wallet debit = 0', async () => {
    const orderId = `A1TEST_FAIL_${Date.now()}`;

    await RechargeTransaction.create({
      orderId,
      userId: testUser._id,
      mobileNumber: '9999988888',
      operatorCode: 'AT',
      circleCode: '1',
      grossAmountPaise: 10000,
      commissionAmountPaise: 100,
      netPayablePaise: 9900,
      amount: 100,
      status: 'PENDING',
      paymentMethod: 'WALLET',
      walletSettlementStatus: 'PENDING',
    });

    await walletService.reserveWalletAmount({ userId: testUser._id, netPayablePaise: 9900, orderId, paymentMethod: 'WALLET' });
    await walletService.releaseOrderHold({ userId: testUser._id, orderId, netPayablePaise: 9900 });

    const walletState = await Wallet.findOne({ userId: testUser._id });
    expect(walletState.balancePaise).toBe(100000); // 0 balance debit
    expect(walletState.onHoldPaise).toBe(0); // Hold released

    const ledgers = await WalletLedger.find({ userId: testUser._id });
    expect(ledgers.length).toBe(0);
  });

  // TEST 4: UPI SUCCESS & WALLET ISOLATION
  it('TEST 4: UPI SUCCESS — produces zero wallet hold and zero wallet debit', async () => {
    const orderId = `A1TEST_UPI_${Date.now()}`;

    await RechargeTransaction.create({
      orderId,
      userId: testUser._id,
      mobileNumber: '9999988888',
      operatorCode: 'AT',
      circleCode: '1',
      grossAmountPaise: 29500,
      commissionAmountPaise: 295,
      netPayablePaise: 29205,
      amount: 295,
      status: 'PENDING',
      paymentMethod: 'RAZORPAY_UPI',
      walletSettlementStatus: 'NONE',
    });

    const reserveRes = await walletService.reserveWalletAmount({
      userId: testUser._id,
      netPayablePaise: 29205,
      orderId,
      paymentMethod: 'RAZORPAY_UPI',
    });
    expect(reserveRes).toBe(true);

    const settleRes = await walletService.settleWalletOrder({
      userId: testUser._id,
      orderId,
      netPayablePaise: 29205,
    });
    expect(settleRes.isUpi).toBe(true);

    const walletState = await Wallet.findOne({ userId: testUser._id });
    expect(walletState.balancePaise).toBe(100000); // 0 debit
    expect(walletState.onHoldPaise).toBe(0); // 0 hold

    const ledgers = await WalletLedger.find({ userId: testUser._id });
    expect(ledgers.length).toBe(0);
  });

  // TEST 5: MISSING SLAB EXCEPTION
  it('TEST 5: MISSING SLAB — querying unconfigured operator throws COMMISSION_CONFIGURATION_NOT_FOUND', async () => {
    await expect(
      commissionService.calculateCommission('UNCONFIGURED_OP', 100, 'Unknown', 'mobile', {
        orderId: 'TEST_ERR',
        accountType: 'BUSINESS',
      })
    ).rejects.toThrow(/COMMISSION_CONFIGURATION_NOT_FOUND/);
  });

  // TEST 6: ACCOUNT TYPE SEPARATION
  it('TEST 6: ACCOUNT TYPE SEPARATION — PERSONAL uses personal slab rate, BUSINESS uses business slab rate', async () => {
    const bizRes = await commissionService.calculateCommission('AT', 100, 'Airtel', 'mobile', { accountType: 'BUSINESS' });
    expect(bizRes.retailerCommissionPercentage).toBe(1.0);
    expect(bizRes.retailerCommissionAmountPaise).toBe(100);

    const personalRes = await commissionService.calculateCommission('AT', 100, 'Airtel', 'mobile', { accountType: 'PERSONAL' });
    expect(personalRes.retailerCommissionPercentage).toBe(0.4);
    expect(personalRes.retailerCommissionAmountPaise).toBe(40);
  });
});
