const mongoose = require('mongoose');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const RechargeTransaction = require('../models/RechargeTransaction');
const CommissionHistory = require('../models/CommissionHistory');
const walletService = require('../services/wallet/wallet.service');
const { processSuccessCommission } = require('../controllers/recharge.controller');
const reconciliationService = require('../services/reconciliation/reconciliation.service');

describe('CRITICAL WALLET SETTLEMENT & FINANCIAL ACCOUNTING SUITE', () => {
  let user;

  beforeAll(async () => {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/a1recharge_test';
    if (mongoose.connection.readyState === 0) {
      await mongoose.connect(mongoUri);
    }
  });

  beforeEach(async () => {
    await User.deleteMany({ phone: '9999900000' });
    await Wallet.deleteMany({});
    await WalletLedger.deleteMany({});
    await RechargeTransaction.deleteMany({});
    await CommissionHistory.deleteMany({});

    user = await User.create({
      name: 'Test Retailer',
      phone: '9999900000',
      retailerId: 'RET99999',
      role: 'retailer',
      accountType: 'BUSINESS',
    });
  });

  afterAll(async () => {
    await User.deleteMany({ phone: '9999900000' });
    await Wallet.deleteMany({});
    await WalletLedger.deleteMany({});
    await RechargeTransaction.deleteMany({});
    await CommissionHistory.deleteMany({});
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
  });

  test('TEST 1: Wallet ₹1000, Recharge ₹295, Commission ₹3 -> Final Wallet ₹708, Debit ₹292, Count 1', async () => {
    // Initial Wallet: ₹1000 (100000 paise)
    await Wallet.create({ userId: user._id, balancePaise: 100000, onHoldPaise: 0 });

    const orderId = `ORD_TEST1_${Date.now()}`;
    const grossPaise = 29500;
    const commPaise = 300;
    const netDebitPaise = grossPaise - commPaise; // 29200 paise (₹292)

    await RechargeTransaction.create({
      orderId,
      userId: user._id,
      paymentMethod: 'WALLET',
      grossAmountPaise: grossPaise,
      commissionAmountPaise: commPaise,
      netPayablePaise: netDebitPaise,
      amount: 295,
      commissionAmount: 3,
      payableAmount: 292,
      mobileNumber: '9876543210',
      operatorCode: 'A',
      circleCode: '1',
      status: 'PENDING',
    });

    // Step 1: Reserve wallet amount
    await walletService.reserveWalletAmount({ userId: user._id, netPayablePaise: netDebitPaise, orderId, paymentMethod: 'WALLET' });

    let walletState = await walletService.getWalletBalancePaise(user._id);
    expect(walletState.walletBalancePaise).toBe(100000);
    expect(walletState.holdAmountPaise).toBe(29200);
    expect(walletState.availablePaise).toBe(70800);

    // Step 2: Provider SUCCESS -> Settle wallet
    await walletService.settleWalletOrder({ userId: user._id, orderId, netPayablePaise: netDebitPaise });

    walletState = await walletService.getWalletBalancePaise(user._id);
    expect(walletState.walletBalancePaise).toBe(70800); // ₹708
    expect(walletState.holdAmountPaise).toBe(0);
    expect(walletState.availablePaise).toBe(70800);

    const debits = await WalletLedger.find({ userId: user._id, transactionType: 'DEBIT' });
    expect(debits.length).toBe(1);
    expect(debits[0].amountPaise).toBe(29200);
  });

  test('TEST 2: Wallet ₹1000, Recharge ₹295, Commission ₹3, Provider FAIL -> Final Wallet ₹1000, Hold ₹0, Debit Count 0', async () => {
    await Wallet.create({ userId: user._id, balancePaise: 100000, onHoldPaise: 0 });

    const orderId = `ORD_TEST2_${Date.now()}`;
    const netDebitPaise = 29200;

    await RechargeTransaction.create({
      orderId,
      userId: user._id,
      paymentMethod: 'WALLET',
      grossAmountPaise: 29500,
      commissionAmountPaise: 300,
      netPayablePaise: netDebitPaise,
      amount: 295,
      commissionAmount: 3,
      payableAmount: 292,
      mobileNumber: '9876543210',
      operatorCode: 'A',
      circleCode: '1',
      status: 'PENDING',
    });

    await walletService.reserveWalletAmount({ userId: user._id, netPayablePaise: netDebitPaise, orderId, paymentMethod: 'WALLET' });
    await walletService.releaseOrderHold({ userId: user._id, orderId, netPayablePaise: netDebitPaise });

    const walletState = await walletService.getWalletBalancePaise(user._id);
    expect(walletState.walletBalancePaise).toBe(100000);
    expect(walletState.holdAmountPaise).toBe(0);
    expect(walletState.availablePaise).toBe(100000);

    const debits = await WalletLedger.find({ userId: user._id, transactionType: 'DEBIT' });
    expect(debits.length).toBe(0);
  });

  test('TEST 3: Wallet ₹0, UPI ₹295, Commission ₹3, Provider SUCCESS -> Wallet remains ₹0, Hold ₹0, Debit 0', async () => {
    await Wallet.create({ userId: user._id, balancePaise: 0, onHoldPaise: 0 });

    const orderId = `ORD_TEST3_${Date.now()}`;
    const netDebitPaise = 29200;

    const txn = await RechargeTransaction.create({
      orderId,
      userId: user._id,
      paymentMethod: 'RAZORPAY_UPI',
      grossAmountPaise: 29500,
      commissionAmountPaise: 300,
      netPayablePaise: netDebitPaise,
      amount: 295,
      commissionAmount: 3,
      payableAmount: 292,
      mobileNumber: '9876543210',
      operatorCode: 'A',
      circleCode: '1',
      status: 'SUCCESS',
    });

    // Attempt settlement call
    const res = await walletService.settleWalletOrder({ userId: user._id, orderId, netPayablePaise: netDebitPaise });
    expect(res.isUpi).toBe(true);

    const walletState = await walletService.getWalletBalancePaise(user._id);
    expect(walletState.walletBalancePaise).toBe(0);
    expect(walletState.holdAmountPaise).toBe(0);
    expect(walletState.availablePaise).toBe(0);

    const debits = await WalletLedger.find({ userId: user._id });
    expect(debits.length).toBe(0);
  });

  test('TEST 4: Wallet ₹500, UPI ₹153, Commission ₹3.06, SUCCESS -> Wallet remains ₹500, Debit 0', async () => {
    await Wallet.create({ userId: user._id, balancePaise: 50000, onHoldPaise: 0 });

    const orderId = `ORD_TEST4_${Date.now()}`;
    const netDebitPaise = 14994; // 15300 - 306

    await RechargeTransaction.create({
      orderId,
      userId: user._id,
      paymentMethod: 'RAZORPAY_UPI',
      grossAmountPaise: 15300,
      commissionAmountPaise: 306,
      netPayablePaise: netDebitPaise,
      amount: 153,
      commissionAmount: 3.06,
      payableAmount: 149.94,
      mobileNumber: '9876543210',
      operatorCode: 'A',
      circleCode: '1',
      status: 'SUCCESS',
    });

    await walletService.settleWalletOrder({ userId: user._id, orderId, netPayablePaise: netDebitPaise });

    const walletState = await walletService.getWalletBalancePaise(user._id);
    expect(walletState.walletBalancePaise).toBe(50000);
    expect(walletState.holdAmountPaise).toBe(0);
    expect(walletState.availablePaise).toBe(50000);

    const debits = await WalletLedger.find({ userId: user._id });
    expect(debits.length).toBe(0);
  });

  test('TEST 5: Send duplicate SUCCESS callback 5 times -> Wallet debit ₹292 exactly ONCE', async () => {
    await Wallet.create({ userId: user._id, balancePaise: 100000, onHoldPaise: 0 });

    const orderId = `ORD_TEST5_${Date.now()}`;
    const netDebitPaise = 29200;

    await RechargeTransaction.create({
      orderId,
      userId: user._id,
      paymentMethod: 'WALLET',
      grossAmountPaise: 29500,
      commissionAmountPaise: 300,
      netPayablePaise: netDebitPaise,
      amount: 295,
      commissionAmount: 3,
      payableAmount: 292,
      mobileNumber: '9876543210',
      operatorCode: 'A',
      circleCode: '1',
      status: 'PENDING',
    });

    await walletService.reserveWalletAmount({ userId: user._id, netPayablePaise: netDebitPaise, orderId, paymentMethod: 'WALLET' });

    // Call settlement 5 times
    for (let i = 0; i < 5; i++) {
      await walletService.settleWalletOrder({ userId: user._id, orderId, netPayablePaise: netDebitPaise });
    }

    const walletState = await walletService.getWalletBalancePaise(user._id);
    expect(walletState.walletBalancePaise).toBe(70800);
    expect(walletState.holdAmountPaise).toBe(0);

    const debits = await WalletLedger.find({ userId: user._id, transactionType: 'DEBIT' });
    expect(debits.length).toBe(1);
    expect(debits[0].amountPaise).toBe(29200);
  });

  test('TEST 6: Concurrent SUCCESS callbacks -> 1 settlement, 1 debit, hold = 0', async () => {
    await Wallet.create({ userId: user._id, balancePaise: 100000, onHoldPaise: 0 });

    const orderId = `ORD_TEST6_${Date.now()}`;
    const netDebitPaise = 29200;

    await RechargeTransaction.create({
      orderId,
      userId: user._id,
      paymentMethod: 'WALLET',
      grossAmountPaise: 29500,
      commissionAmountPaise: 300,
      netPayablePaise: netDebitPaise,
      amount: 295,
      commissionAmount: 3,
      payableAmount: 292,
      mobileNumber: '9876543210',
      operatorCode: 'A',
      circleCode: '1',
      status: 'PENDING',
    });

    await walletService.reserveWalletAmount({ userId: user._id, netPayablePaise: netDebitPaise, orderId, paymentMethod: 'WALLET' });

    // Execute simultaneously
    await Promise.all([
      walletService.settleWalletOrder({ userId: user._id, orderId, netPayablePaise: netDebitPaise }),
      walletService.settleWalletOrder({ userId: user._id, orderId, netPayablePaise: netDebitPaise }),
    ]);

    const walletState = await walletService.getWalletBalancePaise(user._id);
    expect(walletState.walletBalancePaise).toBe(70800);
    expect(walletState.holdAmountPaise).toBe(0);

    const debits = await WalletLedger.find({ userId: user._id, transactionType: 'DEBIT' });
    expect(debits.length).toBe(1);
  });

  test('TEST 7: Wallet recharge FAILED -> Reservation released, no permanent debit', async () => {
    await Wallet.create({ userId: user._id, balancePaise: 100000, onHoldPaise: 0 });

    const orderId = `ORD_TEST7_${Date.now()}`;
    const netDebitPaise = 29200;

    await RechargeTransaction.create({
      orderId,
      userId: user._id,
      paymentMethod: 'WALLET',
      grossAmountPaise: 29500,
      commissionAmountPaise: 300,
      netPayablePaise: netDebitPaise,
      amount: 295,
      commissionAmount: 3,
      payableAmount: 292,
      mobileNumber: '9876543210',
      operatorCode: 'A',
      circleCode: '1',
      status: 'PENDING',
    });

    await walletService.reserveWalletAmount({ userId: user._id, netPayablePaise: netDebitPaise, orderId, paymentMethod: 'WALLET' });
    await walletService.releaseOrderHold({ userId: user._id, orderId, netPayablePaise: netDebitPaise });

    const walletState = await walletService.getWalletBalancePaise(user._id);
    expect(walletState.walletBalancePaise).toBe(100000);
    expect(walletState.holdAmountPaise).toBe(0);
  });

  test('TEST 8: Run reconciliation repeatedly against SUCCESS order -> No additional wallet movement', async () => {
    await Wallet.create({ userId: user._id, balancePaise: 100000, onHoldPaise: 0 });

    const orderId = `ORD_TEST8_${Date.now()}`;
    const netDebitPaise = 29200;

    await RechargeTransaction.create({
      orderId,
      userId: user._id,
      paymentMethod: 'WALLET',
      grossAmountPaise: 29500,
      commissionAmountPaise: 300,
      netPayablePaise: netDebitPaise,
      amount: 295,
      commissionAmount: 3,
      payableAmount: 292,
      mobileNumber: '9876543210',
      operatorCode: 'A',
      circleCode: '1',
      status: 'PENDING',
    });

    await walletService.reserveWalletAmount({ userId: user._id, netPayablePaise: netDebitPaise, orderId, paymentMethod: 'WALLET' });
    await walletService.settleWalletOrder({ userId: user._id, orderId, netPayablePaise: netDebitPaise });

    // Run reconciliation 3 times
    for (let i = 0; i < 3; i++) {
      await reconciliationService.reconcileSingleWallet(user._id);
    }

    const walletState = await walletService.getWalletBalancePaise(user._id);
    expect(walletState.walletBalancePaise).toBe(70800);
    expect(walletState.holdAmountPaise).toBe(0);
  });

  test('TEST 9: Concurrent wallet recharges when balance is insufficient -> Enforce available balance check atomically', async () => {
    // Wallet balance = ₹300 (30000 paise)
    await Wallet.create({ userId: user._id, balancePaise: 30000, onHoldPaise: 0 });

    const orderId1 = `ORD_TEST9_A_${Date.now()}`;
    const orderId2 = `ORD_TEST9_B_${Date.now()}`;

    // Two ₹200 recharges (20000 paise each) -> Total = 40000 paise > 30000 paise
    const p1 = walletService.reserveWalletAmount({ userId: user._id, netPayablePaise: 20000, orderId: orderId1, paymentMethod: 'WALLET' });
    const p2 = walletService.reserveWalletAmount({ userId: user._id, netPayablePaise: 20000, orderId: orderId2, paymentMethod: 'WALLET' });

    const results = await Promise.allSettled([p1, p2]);
    const fulfilled = results.filter(r => r.status === 'fulfilled');
    const rejected = results.filter(r => r.status === 'rejected');

    expect(fulfilled.length).toBe(1);
    expect(rejected.length).toBe(1);

    const walletState = await walletService.getWalletBalancePaise(user._id);
    expect(walletState.walletBalancePaise).toBe(30000);
    expect(walletState.holdAmountPaise).toBe(20000);
    expect(walletState.availablePaise).toBe(10000);
  });

  test('TEST 10: Commission processing repeated multiple times -> Exactly ONE CommissionHistory record', async () => {
    const orderId = `ORD_TEST10_${Date.now()}`;

    const txn = await RechargeTransaction.create({
      orderId,
      userId: user._id,
      paymentMethod: 'WALLET',
      grossAmountPaise: 29500,
      commissionAmountPaise: 300,
      netPayablePaise: 29200,
      amount: 295,
      commissionAmount: 3,
      payableAmount: 292,
      mobileNumber: '9876543210',
      operatorCode: 'A',
      circleCode: '1',
      status: 'SUCCESS',
    });

    // Call processSuccessCommission 3 times
    for (let i = 0; i < 3; i++) {
      await processSuccessCommission({
        transaction: txn,
        userId: user._id,
        orderId,
        mobileNumber: '9876543210',
        operator: { name: 'Airtel' },
        operatorCode: 'A',
        amount: 295,
        serviceType: 'mobile',
      });
    }

    const history = await CommissionHistory.find({ transactionId: txn._id });
    expect(history.length).toBe(1);
  });

  test('TEST 11 (INTEGER TEST): Reject non-integer paise or floating point arithmetic values', async () => {
    await Wallet.create({ userId: user._id, balancePaise: 50000, onHoldPaise: 0 });

    expect(() => {
      walletService._assertIntegerPaise(40767.99999999994, 'testPaise');
    }).toThrow('[FINANCIAL INTEGRITY ERROR]');

    expect(() => {
      walletService._assertIntegerPaise(149.939999999, 'testPaise');
    }).toThrow('[FINANCIAL INTEGRITY ERROR]');

    expect(walletService._assertIntegerPaise(15300, 'testPaise')).toBe(15300);
  });
});
