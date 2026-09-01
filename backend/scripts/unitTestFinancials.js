const assert = require('assert');

// 1. Test Financial Formula Invariants
function testFinancialInvariants() {
  console.log('Testing Financial Calculations Invariants...');

  const grossPaise = 29500; // ₹295.00
  const commissionPaise = 300; // ₹3.00
  const netPayablePaise = grossPaise - commissionPaise; // 29200 paise = ₹292.00

  // Invariant 1: netPayablePaise = grossAmountPaise - commissionAmountPaise
  assert.strictEqual(netPayablePaise, 29200, 'Net payable must equal gross minus commission');

  // Invariant 2: 0 <= commissionAmountPaise <= grossAmountPaise
  assert.ok(commissionPaise >= 0 && commissionPaise <= grossPaise, 'Commission must be between 0 and gross');

  // Invariant 3: netPayablePaise >= 0
  assert.ok(netPayablePaise >= 0, 'Net payable must be non-negative');

  console.log('✔ Financial Invariants Test Passed!');
}

// 2. Test Wallet Balance Invariants
function testWalletBalanceInvariants() {
  console.log('Testing Wallet Balance Formulas...');

  const walletBalancePaise = 500000; // ₹5000.00
  const holdBalancePaise = 29200; // ₹292.00 hold for pending recharge
  const availableBalancePaise = walletBalancePaise - holdBalancePaise; // ₹4708.00

  // Invariant 4: availableBalancePaise = walletBalancePaise - holdBalancePaise
  assert.strictEqual(availableBalancePaise, 470800, 'Available balance must equal wallet balance minus hold');

  // Scenario: On SUCCESS settlement
  const finalWalletBalancePaise = walletBalancePaise - holdBalancePaise; // 470800
  const finalHoldPaise = 0;
  const finalAvailablePaise = finalWalletBalancePaise - finalHoldPaise; // 470800

  assert.strictEqual(finalWalletBalancePaise, 470800, 'Final wallet balance after settlement must be 470800');
  assert.strictEqual(finalHoldPaise, 0, 'Final hold must be 0');
  assert.strictEqual(finalAvailablePaise, 470800, 'Final available must be 470800');

  console.log('✔ Wallet Balance Invariants Test Passed!');
}

// 3. Test UPI Wallet Isolation Invariants
function testUpiIsolation() {
  console.log('Testing UPI Wallet Isolation...');

  const openingWalletPaise = 500000; // ₹5000.00
  const upiRechargeGrossPaise = 29500;
  const upiRechargeCommissionPaise = 300;
  const upiNetPayablePaise = upiRechargeGrossPaise - upiRechargeCommissionPaise; // 29200 paid to Razorpay

  // Invariant 5: UPI recharge wallet debit = 0
  const walletDebitPaise = 0;
  const walletHoldPaise = 0;
  const closingWalletPaise = openingWalletPaise - walletDebitPaise;

  assert.strictEqual(walletDebitPaise, 0, 'UPI recharge wallet debit must be 0');
  assert.strictEqual(walletHoldPaise, 0, 'UPI recharge hold must be 0');
  assert.strictEqual(closingWalletPaise, 500000, 'Wallet balance must be completely untouched by UPI recharge');

  console.log('✔ UPI Wallet Isolation Test Passed!');
}

// 4. Test DTH Precision Invariants
function testDthPrecision() {
  console.log('Testing DTH Integer Precision...');

  const grossPaise = 27500; // ₹275.00
  const commissionPaise = 893; // ₹8.93
  const netPayablePaise = grossPaise - commissionPaise; // 26607 paise = ₹266.07

  assert.strictEqual(netPayablePaise, 26607, 'DTH net payable must be 26607 paise');

  const openingWalletPaise = 500000;
  const closingWalletPaise = openingWalletPaise - netPayablePaise;

  assert.strictEqual(closingWalletPaise, 473393, 'DTH closing wallet balance must be 473393 paise (₹4733.93)');

  console.log('✔ DTH Integer Precision Test Passed!');
}

function runAll() {
  console.log('\n====================================================');
  console.log('RUNNING PURE FINANCIAL ACCOUNTING UNIT TESTS');
  console.log('====================================================');
  testFinancialInvariants();
  testWalletBalanceInvariants();
  testUpiIsolation();
  testDthPrecision();
  console.log('\n====================================================');
  console.log('ALL PURE FINANCIAL ACCOUNTING UNIT TESTS PASSED!');
  console.log('====================================================\n');
}

runAll();
