require('dotenv').config();
const mongoose = require('mongoose');
const Wallet = require('../models/Wallet');
const WalletLedger = require('../models/WalletLedger');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const CommissionHistory = require('../models/CommissionHistory');
const OperatorCommission = require('../models/OperatorCommission');
const User = require('../models/User');

const walletService = require('../services/wallet/wallet.service');
const financialService = require('../services/financial/financial.service');

async function runTests() {
  const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge_test';
  console.log(`[TEST RUNNER] Connecting to MongoDB: ${mongoUri}...`);
  await mongoose.connect(mongoUri);

  try {
    // Clean collections
    await Wallet.deleteMany({});
    await WalletLedger.deleteMany({});
    await RechargeTransaction.deleteMany({});
    await Transaction.deleteMany({});
    await CommissionHistory.deleteMany({});
    await User.deleteMany({});
    await OperatorCommission.deleteMany({});

    // Seed test commissions
    await OperatorCommission.create({
      accountType: 'BUSINESS',
      operatorCode: 'RC',
      operatorName: 'JIO',
      serviceType: 'mobile',
      providerCommission: 4,
      retailerCommission: 1.0169491525, // ₹3 commission on ₹295
      companyCommission: 2.9830508475,
      status: 'ACTIVE',
    });

    await OperatorCommission.create({
      accountType: 'BUSINESS',
      operatorCode: 'TTV',
      operatorName: 'TATA SKY',
      serviceType: 'dth',
      providerCommission: 4,
      retailerCommission: 3.247272727, // ₹8.93 commission on ₹275
      companyCommission: 0.752727273,
      status: 'ACTIVE',
    });

    const testUser = await User.create({
      name: 'Test Retailer',
      phoneNumber: '9876543210',
      accountType: 'BUSINESS',
      role: 'retailer',
    });

    console.log('\n----------------------------------------------------');
    console.log('RUNNING SCENARIO TEST 1: WALLET RECHARGE SUCCESS');
    console.log('----------------------------------------------------');
    await Wallet.create({ userId: testUser._id, balancePaise: 500000, onHoldPaise: 0 });

    const fin1 = await financialService.calculateRechargeFinancials({
      serviceType: 'mobile',
      operatorCode: 'RC',
      operatorName: 'JIO',
      grossAmountPaise: 29500,
      userId: testUser._id,
    });

    console.log('Financial Calculation Result:', fin1);
    console.assert(fin1.grossAmountPaise === 29500, 'Gross must be 29500 paise');
    console.assert(fin1.commissionAmountPaise === 300, 'Commission must be 300 paise');
    console.assert(fin1.netPayablePaise === 29200, 'Net payable must be 29200 paise');

    const orderId1 = 'A1TEST001';
    await RechargeTransaction.create({
      orderId: orderId1,
      userId: testUser._id,
      grossAmountPaise: fin1.grossAmountPaise,
      commissionAmountPaise: fin1.commissionAmountPaise,
      netPayablePaise: fin1.netPayablePaise,
      amount: 295,
      commissionAmount: 3,
      payableAmount: 292,
      operatorCode: 'RC',
      circleCode: '4',
      status: 'PENDING',
      paymentMethod: 'WALLET',
      mobileNumber: '9876543210',
    });

    await walletService.reserveWalletAmount({ userId: testUser._id, netPayablePaise: fin1.netPayablePaise, orderId: orderId1 });

    let w1 = await walletService.getWalletBalancePaise(testUser._id);
    console.log('After Reservation:', w1);
    console.assert(w1.walletBalancePaise === 500000, 'Ledger balance remains 500000 paise');
    console.assert(w1.holdAmountPaise === 29200, 'Hold must be 29200 paise');
    console.assert(w1.availablePaise === 470800, 'Available balance must be 470800 paise (₹4708.00)');

    await walletService.settleWalletOrder({ userId: testUser._id, orderId: orderId1, netPayablePaise: fin1.netPayablePaise });

    w1 = await walletService.getWalletBalancePaise(testUser._id);
    console.log('After Settlement:', w1);
    console.assert(w1.walletBalancePaise === 470800, 'Final ledger balance must be 470800 paise (₹4708.00)');
    console.assert(w1.holdAmountPaise === 0, 'Final hold must be 0 paise');
    console.assert(w1.availablePaise === 470800, 'Final available must be 470800 paise');

    console.log('\n----------------------------------------------------');
    console.log('RUNNING SCENARIO TEST 4: DUPLICATE CALLBACK IDEMPOTENCY');
    console.log('----------------------------------------------------');
    const resDup = await walletService.settleWalletOrder({ userId: testUser._id, orderId: orderId1, netPayablePaise: fin1.netPayablePaise });
    console.log('Duplicate Settlement Result:', resDup);
    console.assert(resDup.alreadySettled === true, 'Duplicate settlement must be idempotent no-op');

    w1 = await walletService.getWalletBalancePaise(testUser._id);
    console.assert(w1.walletBalancePaise === 470800, 'Wallet balance remains 470800 (NO DOUBLE DEBIT)');

    console.log('\n----------------------------------------------------');
    console.log('RUNNING SCENARIO TEST 5: WALLET RECHARGE FAILED');
    console.log('----------------------------------------------------');
    await Wallet.updateOne({ userId: testUser._id }, { balancePaise: 500000, onHoldPaise: 0 });
    const orderId5 = 'A1TEST005';
    await RechargeTransaction.create({
      orderId: orderId5,
      userId: testUser._id,
      grossAmountPaise: 29500,
      commissionAmountPaise: 300,
      netPayablePaise: 29200,
      amount: 295,
      payableAmount: 292,
      operatorCode: 'RC',
      circleCode: '4',
      status: 'PENDING',
      paymentMethod: 'WALLET',
      mobileNumber: '9876543210',
    });

    await walletService.reserveWalletAmount({ userId: testUser._id, netPayablePaise: 29200, orderId: orderId5 });
    await walletService.releaseOrderHold({ userId: testUser._id, orderId: orderId5, netPayablePaise: 29200 });

    let w5 = await walletService.getWalletBalancePaise(testUser._id);
    console.log('After Failed Hold Release:', w5);
    console.assert(w5.walletBalancePaise === 500000, 'Wallet balance remains 500000 (0 permanent debit)');
    console.assert(w5.holdAmountPaise === 0, 'Hold released to 0');

    console.log('\n----------------------------------------------------');
    console.log('RUNNING SCENARIO TEST 6 & 7: UPI RECHARGE NO WALLET MUTATION');
    console.log('----------------------------------------------------');
    const orderId6 = 'A1TEST006';
    await RechargeTransaction.create({
      orderId: orderId6,
      userId: testUser._id,
      grossAmountPaise: 29500,
      commissionAmountPaise: 300,
      netPayablePaise: 29200,
      amount: 295,
      payableAmount: 292,
      operatorCode: 'RC',
      circleCode: '4',
      status: 'SUCCESS',
      paymentMethod: 'RAZORPAY_UPI',
      razorpayPaymentId: 'pay_upi_123',
      mobileNumber: '9876543210',
    });

    let w6 = await walletService.getWalletBalancePaise(testUser._id);
    console.assert(w6.walletBalancePaise === 500000, 'UPI success MUST NOT debit wallet balance');

    console.log('\n----------------------------------------------------');
    console.log('RUNNING SCENARIO TEST 8: DTH INTEGER PRECISION');
    console.log('----------------------------------------------------');
    const fin8 = await financialService.calculateRechargeFinancials({
      serviceType: 'dth',
      operatorCode: 'TTV',
      operatorName: 'TATA SKY',
      grossAmountPaise: 27500,
      userId: testUser._id,
    });

    console.log('DTH Financial Calculation:', fin8);
    console.assert(fin8.grossAmountPaise === 27500, 'DTH gross 27500 paise');
    console.assert(fin8.commissionAmountPaise === 893, 'DTH commission 893 paise');
    console.assert(fin8.netPayablePaise === 26607, 'DTH net payable 26607 paise');

    const orderId8 = 'A1DTH008';
    await RechargeTransaction.create({
      orderId: orderId8,
      userId: testUser._id,
      grossAmountPaise: fin8.grossAmountPaise,
      commissionAmountPaise: fin8.commissionAmountPaise,
      netPayablePaise: fin8.netPayablePaise,
      amount: 275,
      payableAmount: 266.07,
      operatorCode: 'TTV',
      circleCode: '4',
      serviceType: 'dth',
      status: 'PENDING',
      paymentMethod: 'WALLET',
      mobileNumber: '9876543210',
    });

    await walletService.reserveWalletAmount({ userId: testUser._id, netPayablePaise: fin8.netPayablePaise, orderId: orderId8 });
    await walletService.settleWalletOrder({ userId: testUser._id, orderId: orderId8, netPayablePaise: fin8.netPayablePaise });

    let w8 = await walletService.getWalletBalancePaise(testUser._id);
    console.log('DTH Final Wallet State:', w8);
    console.assert(w8.walletBalancePaise === 500000 - 26607, `DTH wallet balance ${500000 - 26607} paise (₹4733.93)`);

    console.log('\n----------------------------------------------------');
    console.log('ALL FINANCIAL ACCOUNTING SCENARIOS PASSED PERFECTLY!');
    console.log('----------------------------------------------------\n');

  } finally {
    await mongoose.disconnect();
  }
}

runTests().catch(err => {
  console.error('TEST RUNNER FAILED:', err);
  process.exit(1);
});
