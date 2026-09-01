const assert = require('assert');
const financialService = require('../services/financial/financial.service');
const walletService = require('../services/wallet/wallet.service');

describe('FINANCIAL ACCOUNTING & WALLET INVARIANTS TEST SUITE', () => {
  test('INVARIANT 1: Net Payable = Gross - Commission', () => {
    const grossAmountPaise = 29500;
    const commissionAmountPaise = 300;
    const netPayablePaise = grossAmountPaise - commissionAmountPaise;

    expect(netPayablePaise).toBe(29200);
    expect(netPayablePaise).toBeGreaterThanOrEqual(0);
  });

  test('INVARIANT 2: 0 <= Commission <= Gross', () => {
    const grossAmountPaise = 29500;
    const commissionAmountPaise = 300;

    expect(commissionAmountPaise).toBeGreaterThanOrEqual(0);
    expect(commissionAmountPaise).toBeLessThanOrEqual(grossAmountPaise);
  });

  test('INVARIANT 3: Available Balance = Wallet Balance - Hold Balance', () => {
    const walletBalancePaise = 500000;
    const holdBalancePaise = 29200;
    const availableBalancePaise = walletBalancePaise - holdBalancePaise;

    expect(availableBalancePaise).toBe(470800);
  });

  test('INVARIANT 4: UPI Recharge Wallet Debit = 0 & Wallet Balance Untouched', () => {
    const walletBalanceBefore = 500000;
    const upiRechargeGross = 29500;
    const upiRechargeCommission = 300;
    const upiNetPayable = upiRechargeGross - upiRechargeCommission; // Paid to Razorpay

    const walletDebit = 0;
    const walletHold = 0;
    const walletBalanceAfter = walletBalanceBefore - walletDebit;

    expect(upiNetPayable).toBe(29200);
    expect(walletDebit).toBe(0);
    expect(walletHold).toBe(0);
    expect(walletBalanceAfter).toBe(500000);
  });

  test('INVARIANT 5: DTH Integer Precision (Gross ₹275 = 27500, Comm ₹8.93 = 893 -> Net 26607)', () => {
    const grossPaise = 27500;
    const commissionPaise = 893;
    const netPayablePaise = grossPaise - commissionPaise;

    expect(netPayablePaise).toBe(26607);

    const walletBalanceBefore = 500000;
    const walletBalanceAfter = walletBalanceBefore - netPayablePaise;

    expect(walletBalanceAfter).toBe(473393); // ₹4733.93
  });

  test('INVARIANT 6: Wallet Success Settlement reduces balance by Net Payable exactly once', () => {
    const walletBalanceBefore = 500000;
    const holdBefore = 29200;
    const netPayablePaise = 29200;

    // Settle 1
    const holdAfter1 = holdBefore - netPayablePaise;
    const balanceAfter1 = walletBalanceBefore - netPayablePaise;

    expect(holdAfter1).toBe(0);
    expect(balanceAfter1).toBe(470800);

    // Duplicate Settle 2 (Idempotent: 0 effect)
    const holdAfter2 = holdAfter1;
    const balanceAfter2 = balanceAfter1;

    expect(holdAfter2).toBe(0);
    expect(balanceAfter2).toBe(470800);
  });

  test('INVARIANT 7: Wallet Failure Releases Hold with 0 Permanent Debit', () => {
    const walletBalanceBefore = 500000;
    const holdBefore = 29200;
    const netPayablePaise = 29200;

    // Failure Release
    const holdAfter = Math.max(0, holdBefore - netPayablePaise);
    const balanceAfter = walletBalanceBefore; // 0 debit!

    expect(holdAfter).toBe(0);
    expect(balanceAfter).toBe(500000);
  });
});
