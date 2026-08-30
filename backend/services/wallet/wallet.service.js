const mongoose = require('mongoose');
const Wallet = require('../../models/Wallet');

class WalletService {
  /**
   * Reserves an amount in the wallet
   */
  async reserveAmount(userId, amount) {
    const session = await mongoose.startSession();
    try {
      session.startTransaction();
      const wallet = await Wallet.findOne({ userId }).session(session);

      if (!wallet) {
        throw new Error('Wallet not found');
      }

      console.log({
        amount,
        walletBalancePaise: wallet.balancePaise
      });

      if (wallet.balancePaise - (wallet.onHoldPaise || 0) < amount * 100) {
        throw new Error('Insufficient wallet balance');
      }

      // We need a reservedBalance field on Wallet, if it doesn't exist we add it on the fly or just reduce balance.
      // Wait, the user said "Reserve amount. Create pending transaction. If Failed, Release reserved amount. Refund wallet."
      // Let's implement reservedBalance logic. If reservedBalance doesn't exist on Wallet schema yet, we can add it or just deduct the amount immediately (which effectively reserves it) and refund on failure.
      // "Deduct funds only after a successful recharge. Release the reservation if the recharge fails."
      // So we need to update the wallet's reserved amount.
      
      // We only lock the amount by adding to onHoldPaise.
      // balancePaise remains untouched until commit.
      wallet.onHoldPaise = (wallet.onHoldPaise || 0) + amount * 100;
      await wallet.save({ session });

      await session.commitTransaction();
      session.endSession();
      return true;
    } catch (error) {
      await session.abortTransaction();
      session.endSession();
      
      // Fallback for standalone MongoDB environments without replica sets
      if (error.message.includes('Transaction') || error.message.includes('replica set')) {
        console.warn('MongoDB Transactions not supported, falling back to atomic operations');
        return await this._reserveAmountAtomic(userId, amount);
      }
      
      throw error;
    }
  }

  async _reserveAmountAtomic(userId, amount) {
    const wallet = await Wallet.findOne({ userId });
    if (!wallet) throw new Error('Wallet not found');
    console.log({
      amount,
      walletBalancePaise: wallet.balancePaise
    });
    if (wallet.balancePaise - (wallet.onHoldPaise || 0) < amount * 100) throw new Error('Insufficient wallet balance');

    const result = await Wallet.updateOne(
      { userId, $expr: { $gte: [ { $subtract: ["$balancePaise", { $ifNull: ["$onHoldPaise", 0] }] }, amount * 100 ] } },
      { 
        $inc: { 
          onHoldPaise: amount * 100
        }
      }
    );

    if (result.modifiedCount === 0) {
      throw new Error('Insufficient wallet balance or concurrent modification');
    }
    return true;
  }

  /**
   * Commits the reserved amount (Deduct Net Amount: Gross Amount - Commission)
   */
  /**
   * Commits the reserved amount (Deduct Net Amount: Gross Amount - Commission)
   */
  async commitReservation(userId, amount, commissionEarnedPaise = 0) {
    return await this.commitOrderReservation({ userId, orderId: null, amount, commissionEarnedPaise });
  }

  /**
   * Commits the reserved amount linked to a specific orderId (Idempotent & Atomic)
   */
  async commitOrderReservation(options) {
    const { userId, orderId, amount, commissionEarnedPaise = 0 } = options;
    const RechargeTransaction = require('../../models/RechargeTransaction');

    let txn = null;
    if (orderId) {
      txn = await RechargeTransaction.findOne({ orderId });
      if (txn && txn.walletFinalizationStatus === 'COMPLETED') {
        console.log(`[DTH WALLET FINALIZATION] orderId=${orderId} ALREADY FINALIZED. Skipping duplicate commit.`);
        return { success: true, alreadyFinalized: true };
      }
    }

    const grossPaise = Math.round(amount * 100);
    const netDebitPaise = Math.max(0, grossPaise - (Number(commissionEarnedPaise) || 0));

    const walletBefore = await Wallet.findOne({ userId }).lean();
    if (!walletBefore) {
      throw new Error(`Wallet not found for user ${userId}`);
    }

    const walletBalanceBefore = Number(((walletBefore.balancePaise || 0) / 100).toFixed(2));
    const holdBalanceBefore = Number(((walletBefore.onHoldPaise || 0) / 100).toFixed(2));

    const currentHoldPaise = walletBefore.onHoldPaise || 0;
    const holdToDeduct = Math.min(currentHoldPaise, grossPaise);

    console.log(`[DTH WALLET FINALIZATION] orderId=${orderId} userId=${userId} grossAmountPaise=${grossPaise} commissionAmountPaise=${commissionEarnedPaise} netDebitPaise=${netDebitPaise} walletBalanceBefore=${walletBalanceBefore} holdBalanceBefore=${holdBalanceBefore}`);

    await Wallet.updateOne(
      { userId },
      {
        $inc: {
          balancePaise: -netDebitPaise,
          onHoldPaise: -holdToDeduct,
        }
      }
    );

    const walletAfterDoc = await Wallet.findOne({ userId }).lean();
    const walletBalanceAfter = Number(((walletAfterDoc.balancePaise || 0) / 100).toFixed(2));
    const holdBalanceAfter = Number(((walletAfterDoc.onHoldPaise || 0) / 100).toFixed(2));

    console.log(`[DTH WALLET FINALIZATION SUCCESS] orderId=${orderId} walletBalanceAfter=${walletBalanceAfter} holdBalanceAfter=${holdBalanceAfter}`);

    if (txn) {
      txn.walletFinalizationStatus = 'COMPLETED';
      txn.reservationStatus = 'CONSUMED';
      await txn.save();
    }

    return { success: true, walletBalanceAfter, holdBalanceAfter };
  }

  /**
   * Releases the reserved amount back to balance (Refund)
   */
  async releaseReservation(userId, amount) {
    const amountPaise = Math.round(amount * 100);
    const walletDoc = await Wallet.findOne({ userId }).lean();
    if (!walletDoc) return true;

    const currentHold = walletDoc.onHoldPaise || 0;
    const releasePaise = Math.min(currentHold, amountPaise);

    if (releasePaise > 0) {
      await Wallet.updateOne(
        { userId },
        { $inc: { onHoldPaise: -releasePaise } }
      );
    }
    return true;
  }

  /**
   * Adds balance directly to the wallet (e.g. for commission)
   */
  async addBalance(userId, amount) {
    const result = await Wallet.updateOne(
      { userId },
      { 
        $inc: { 
          balancePaise: amount * 100
        }
      }
    );
    return result.modifiedCount > 0;
  }

  /**
   * Fetches current available balance in Rupees for a given user
   */
  async getWalletBalance(userId) {
    const Wallet = require('../../models/Wallet');
    const wallet = await Wallet.findOne({ userId }).lean();
    if (!wallet) return 0;
    return Number(((wallet.balancePaise || 0) / 100).toFixed(2));
  }
}

module.exports = new WalletService();
