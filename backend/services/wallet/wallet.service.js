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
   * Commits the reserved amount (Deduct)
   */
  async commitReservation(userId, amount) {
    const result = await Wallet.updateOne(
      { userId, onHoldPaise: { $gte: amount * 100 } },
      { 
        $inc: { 
          balancePaise: -amount * 100,
          onHoldPaise: -amount * 100
        }
      }
    );
    if (result.modifiedCount === 0) {
      throw new Error(`Invalid wallet state: Cannot commit reservation for user ${userId}. Insufficient hold balance or wallet not found.`);
    }
    return true;
  }

  /**
   * Releases the reserved amount back to balance (Refund)
   */
  async releaseReservation(userId, amount) {
    const result = await Wallet.updateOne(
      { userId, onHoldPaise: { $gte: amount * 100 } },
      { 
        $inc: { 
          onHoldPaise: -amount * 100
        }
      }
    );
    if (result.modifiedCount === 0) {
      throw new Error(`Invalid wallet state: Cannot release reservation for user ${userId}. Insufficient hold balance or wallet not found.`);
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
}

module.exports = new WalletService();
