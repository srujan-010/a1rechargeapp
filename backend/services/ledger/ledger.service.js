const WalletLedger = require('../../models/WalletLedger');
const Wallet = require('../../models/Wallet');

class LedgerService {
  /**
   * Log a transaction in the immutable ledger
   */
  async logTransaction({ userId, type, amount, referenceType, referenceId, description }) {
    const wallet = await Wallet.findOne({ userId });
    
    if (!wallet) {
      throw new Error('Wallet not found during ledger logging');
    }

    const ledgerEntry = new WalletLedger({
      userId,
      transactionType: type, // 'CREDIT' or 'DEBIT'
      amount,
      balanceAfter: wallet.balancePaise / 100, // Converting back to standard currency unit for ledger readability
      referenceType,
      referenceId,
      description,
    });

    await ledgerEntry.save();
    return ledgerEntry;
  }
}

module.exports = new LedgerService();
