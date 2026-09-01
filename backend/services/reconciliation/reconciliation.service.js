const Wallet = require('../../models/Wallet');
const WalletLedger = require('../../models/WalletLedger');
const RechargeTransaction = require('../../models/RechargeTransaction');

class ReconciliationService {
  /**
   * Run financial audit & reconciliation across all retailer wallets.
   * Compares stored wallet balance against WalletLedger history and active holds.
   * Non-destructive: logs discrepancies clearly without mutating data blindly.
   */
  async reconcileAllWallets() {
    const wallets = await Wallet.find().lean();
    const results = {
      totalWalletsAudited: wallets.length,
      balancedWallets: 0,
      discrepantWallets: [],
      timestamp: new Date().toISOString(),
    };

    for (const wallet of wallets) {
      const audit = await this.reconcileSingleWallet(wallet.userId);
      if (audit.isBalanced) {
        results.balancedWallets++;
      } else {
        results.discrepantWallets.push(audit);
      }
    }

    console.log(`\n====================================================`);
    console.log(`[RECONCILIATION AUDIT SUMMARY]`);
    console.log(`Total Wallets Audited: ${results.totalWalletsAudited}`);
    console.log(`Balanced Wallets: ${results.balancedWallets}`);
    console.log(`Discrepant Wallets: ${results.discrepantWallets.length}`);
    console.log(`====================================================\n`);

    return results;
  }

  /**
   * Audit a single wallet given a userId.
   */
  async reconcileSingleWallet(userId) {
    const wallet = await Wallet.findOne({ userId }).lean();
    if (!wallet) {
      return { isBalanced: true, message: 'Wallet not found' };
    }

    const storedBalancePaise = Math.round(wallet.balancePaise || 0);
    const storedHoldPaise = Math.round(wallet.onHoldPaise || 0);
    const storedAvailablePaise = Math.max(0, storedBalancePaise - storedHoldPaise);

    // Calculate expected ledger balance by summing ALL CREDIT and DEBIT entries
    const ledgerEntries = await WalletLedger.find({ userId }).lean();

    let expectedLedgerBalancePaise = 0;
    for (const entry of ledgerEntries) {
      const amountPaise = entry.amountPaise != null
        ? Math.round(entry.amountPaise)
        : Math.round((entry.amount || 0) * 100);

      if (entry.transactionType === 'CREDIT') {
        expectedLedgerBalancePaise += amountPaise;
      } else if (entry.transactionType === 'DEBIT') {
        expectedLedgerBalancePaise -= amountPaise;
      }
    }

    // Calculate expected active hold balance by summing active PENDING wallet recharges
    const activePendingTransactions = await RechargeTransaction.find({
      userId,
      paymentMethod: { $in: ['WALLET', 'wallet'] },
      status: { $in: ['PENDING', 'PROCESSING', 'RECHARGE_PROCESSING', 'INITIATED'] },
      walletSettlementStatus: { $ne: 'SETTLED' },
    }).lean();

    let expectedHoldPaise = 0;
    for (const txn of activePendingTransactions) {
      const holdPaise = txn.reservedAmountPaise != null
        ? Math.round(txn.reservedAmountPaise)
        : (txn.netPayablePaise || Math.round((txn.payableAmount || txn.amount) * 100));
      expectedHoldPaise += holdPaise;
    }

    const expectedAvailablePaise = expectedLedgerBalancePaise - expectedHoldPaise;

    const isBalanceMatch = storedBalancePaise === expectedLedgerBalancePaise;
    const isHoldMatch = storedHoldPaise === expectedHoldPaise;
    const isBalanced = isBalanceMatch && isHoldMatch;

    return {
      userId: String(userId),
      storedBalancePaise,
      expectedLedgerBalancePaise,
      storedHoldPaise,
      expectedHoldPaise,
      storedAvailablePaise,
      expectedAvailablePaise,
      isBalanceMatch,
      isHoldMatch,
      isBalanced,
      balanceDiscrepancyPaise: storedBalancePaise - expectedLedgerBalancePaise,
      holdDiscrepancyPaise: storedHoldPaise - expectedHoldPaise,
      activePendingCount: activePendingTransactions.length,
      ledgerEntriesCount: ledgerEntries.length,
    };
  }
}

module.exports = new ReconciliationService();
