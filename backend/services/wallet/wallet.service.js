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

      if (wallet.balancePaise < amount * 100) {
        throw new Error('Insufficient wallet balance');
      }

      // We need a reservedBalance field on Wallet, if it doesn't exist we add it on the fly or just reduce balance.
      // Wait, the user said "Reserve amount. Create pending transaction. If Failed, Release reserved amount. Refund wallet."
      // Let's implement reservedBalance logic. If reservedBalance doesn't exist on Wallet schema yet, we can add it or just deduct the amount immediately (which effectively reserves it) and refund on failure.
      // "Deduct funds only after a successful recharge. Release the reservation if the recharge fails."
      // So we need to update the wallet's reserved amount.
      
      // We will deduct the amount from balancePaise, and keep it conceptually reserved. On failure we refund it.
      // Or we can dynamically add `reservedPaise` to the Wallet document.
      wallet.balancePaise -= amount * 100;
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
    if (wallet.balancePaise < amount * 100) throw new Error('Insufficient wallet balance');

    const result = await Wallet.updateOne(
      { userId, balancePaise: { $gte: amount * 100 } },
      { 
        $inc: { 
          balancePaise: -amount * 100,
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
      { userId },
      { 
        $inc: { 
          onHoldPaise: -amount * 100
        }
      }
    );
    return result.modifiedCount > 0;
  }

  /**
   * Releases the reserved amount back to balance (Refund)
   */
  async releaseReservation(userId, amount) {
    const result = await Wallet.updateOne(
      { userId },
      { 
        $inc: { 
          balancePaise: amount * 100,
          onHoldPaise: -amount * 100
        }
      }
    );
    return result.modifiedCount > 0;
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
