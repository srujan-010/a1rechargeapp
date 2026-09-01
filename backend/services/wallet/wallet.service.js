const mongoose = require('mongoose');
const Wallet = require('../../models/Wallet');
const WalletLedger = require('../../models/WalletLedger');
const RechargeTransaction = require('../../models/RechargeTransaction');
const CommissionHistory = require('../../models/CommissionHistory');
const commissionService = require('../commission/commission.service');

class WalletService {
  /**
   * Fetches full wallet balance object for a given user in Integer Paise.
   */
  async getWalletBalancePaise(userId) {
    let wallet = await Wallet.findOne({ userId }).lean();
    if (!wallet) {
      wallet = await Wallet.create({ userId, balancePaise: 0, onHoldPaise: 0, currency: 'INR' });
    }
    const balancePaise = Math.round(wallet.balancePaise || 0);
    const holdAmountPaise = Math.round(wallet.onHoldPaise || 0);
    const availablePaise = Math.max(0, balancePaise - holdAmountPaise);

    return {
      walletBalancePaise: balancePaise,
      holdAmountPaise,
      availablePaise,
      currency: wallet.currency || 'INR',
    };
  }

  /**
   * Legacy helper returning available balance in Rupees (formatted to 2 decimals)
   */
  async getWalletBalance(userId) {
    const { availablePaise } = await this.getWalletBalancePaise(userId);
    return Number((availablePaise / 100).toFixed(2));
  }

  /**
   * Reserves Net Retailer Payable amount in the wallet (onHoldPaise += netPayablePaise).
   * Does NOT deduct from balancePaise.
   */
  async reserveWalletAmount({ userId, netPayablePaise, orderId }) {
    const netPaise = Math.round(Number(netPayablePaise) || 0);

    if (!Number.isInteger(netPaise) || netPaise <= 0) {
      throw new Error(`Invalid reservation net payable amount paise: ${netPayablePaise}`);
    }

    const session = await mongoose.startSession();
    try {
      session.startTransaction();

      let wallet = await Wallet.findOne({ userId }).session(session);
      if (!wallet) {
        throw new Error('Wallet not found for user');
      }

      const available = Math.max(0, (wallet.balancePaise || 0) - (wallet.onHoldPaise || 0));
      if (available < netPaise) {
        const shortfallPaise = netPaise - available;
        const err = new Error(`Insufficient wallet balance. Shortfall: ₹${(shortfallPaise / 100).toFixed(2)}`);
        err.shortfallPaise = shortfallPaise;
        err.availablePaise = available;
        err.netPayablePaise = netPaise;
        throw err;
      }

      wallet.onHoldPaise = Math.round((wallet.onHoldPaise || 0) + netPaise);
      await wallet.save({ session });

      if (orderId) {
        await RechargeTransaction.updateOne(
          { orderId },
          {
            $set: {
              reservedAmountPaise: netPaise,
              reservedAmount: Number((netPaise / 100).toFixed(2)),
              reservationStatus: 'ACTIVE',
              walletSettlementStatus: 'PENDING',
            }
          },
          { session }
        );
      }

      await session.commitTransaction();
      session.endSession();

      console.log(`[WALLET RESERVED SUCCESS] orderId=${orderId} userId=${userId} reservedNetPaise=${netPaise} newHoldPaise=${wallet.onHoldPaise}`);
      return true;
    } catch (error) {
      await session.abortTransaction();
      session.endSession();

      if (error.message.includes('Transaction') || error.message.includes('replica set')) {
        console.warn('[WALLET RESERVATION] Falling back to atomic updateOne...');
        return await this._reserveWalletAmountAtomic({ userId, netPayablePaise: netPaise, orderId });
      }

      throw error;
    }
  }

  async _reserveWalletAmountAtomic({ userId, netPayablePaise, orderId }) {
    const netPaise = Math.round(Number(netPayablePaise) || 0);

    const result = await Wallet.updateOne(
      {
        userId,
        $expr: {
          $gte: [
            { $subtract: ["$balancePaise", { $ifNull: ["$onHoldPaise", 0] }] },
            netPaise
          ]
        }
      },
      {
        $inc: { onHoldPaise: netPaise }
      }
    );

    if (result.modifiedCount === 0) {
      const wallet = await Wallet.findOne({ userId }).lean();
      const avail = wallet ? Math.max(0, (wallet.balancePaise || 0) - (wallet.onHoldPaise || 0)) : 0;
      const shortfallPaise = Math.max(0, netPaise - avail);
      const err = new Error(`Insufficient wallet balance. Shortfall: ₹${(shortfallPaise / 100).toFixed(2)}`);
      err.shortfallPaise = shortfallPaise;
      err.availablePaise = avail;
      err.netPayablePaise = netPaise;
      throw err;
    }

    if (orderId) {
      await RechargeTransaction.updateOne(
        { orderId },
        {
          $set: {
            reservedAmountPaise: netPaise,
            reservedAmount: Number((netPaise / 100).toFixed(2)),
            reservationStatus: 'ACTIVE',
            walletSettlementStatus: 'PENDING',
          }
        }
      );
    }

    return true;
  }

  /**
   * Settles a WALLET recharge transaction EXACTLY ONCE.
   * Atomically converts the hold into a single permanent debit.
   */
  async settleWalletOrder({ userId, orderId, netPayablePaise }) {
    if (!orderId) {
      throw new Error('orderId is required for wallet settlement');
    }

    // 1. Idempotency Check: Verify if order is already settled
    const txn = await RechargeTransaction.findOne({ orderId });
    if (!txn) {
      throw new Error(`RechargeTransaction not found for orderId ${orderId}`);
    }

    if (txn.walletSettlementStatus === 'SETTLED' || txn.walletFinalizationStatus === 'COMPLETED') {
      console.log(`[WALLET SETTLEMENT IDEMPOTENT] orderId=${orderId} is ALREADY SETTLED. Skipping duplicate settlement.`);
      return { success: true, alreadySettled: true };
    }

    const netDebitPaise = Math.round(Number(netPayablePaise || txn.netPayablePaise || (txn.payableAmount * 100)) || 0);

    if (netDebitPaise <= 0) {
      throw new Error(`Invalid net debit paise (${netDebitPaise}) for order ${orderId}`);
    }

    const session = await mongoose.startSession();
    try {
      session.startTransaction();

      // Lock transaction document atomically
      const lockedTxn = await RechargeTransaction.findOneAndUpdate(
        {
          _id: txn._id,
          walletSettlementStatus: { $ne: 'SETTLED' }
        },
        {
          $set: { walletSettlementStatus: 'PENDING' }
        },
        { session, new: true }
      );

      if (!lockedTxn) {
        await session.abortTransaction();
        session.endSession();
        console.log(`[WALLET SETTLEMENT CONCURRENCY] orderId=${orderId} lock was acquired by concurrent execution.`);
        return { success: true, alreadySettled: true };
      }

      const wallet = await Wallet.findOne({ userId }).session(session);
      if (!wallet) {
        throw new Error(`Wallet not found for userId ${userId}`);
      }

      const walletBalanceBeforePaise = Math.round(wallet.balancePaise || 0);
      const holdBeforePaise = Math.round(wallet.onHoldPaise || 0);
      const availableBeforePaise = Math.max(0, walletBalanceBeforePaise - holdBeforePaise);

      // Hold reduction is capped by current onHoldPaise to prevent negative hold
      const holdToReleasePaise = Math.min(holdBeforePaise, netDebitPaise);

      wallet.balancePaise = Math.round(walletBalanceBeforePaise - netDebitPaise);
      wallet.onHoldPaise = Math.round(holdBeforePaise - holdToReleasePaise);
      await wallet.save({ session });

      const walletBalanceAfterPaise = wallet.balancePaise;
      const holdAfterPaise = wallet.onHoldPaise;
      const availableAfterPaise = Math.max(0, walletBalanceAfterPaise - holdAfterPaise);

      // Create EXACTLY ONE WalletLedger Entry
      let ledgerEntry = await WalletLedger.findOne({
        userId,
        referenceType: 'RECHARGE',
        referenceId: lockedTxn._id,
        transactionType: 'DEBIT'
      }).session(session);

      if (!ledgerEntry) {
        ledgerEntry = await WalletLedger.create(
          [
            {
              userId,
              transactionType: 'DEBIT',
              amountPaise: netDebitPaise,
              previousBalancePaise: walletBalanceBeforePaise,
              balanceAfterPaise: walletBalanceAfterPaise,
              amount: Number((netDebitPaise / 100).toFixed(2)),
              previousBalance: Number((walletBalanceBeforePaise / 100).toFixed(2)),
              balanceAfter: Number((walletBalanceAfterPaise / 100).toFixed(2)),
              referenceType: 'RECHARGE',
              referenceId: lockedTxn._id,
              description: `Recharge for ${lockedTxn.mobileNumber} - Order ID: ${lockedTxn.orderId}`,
              remark: 'NET_PAYABLE_DEBIT',
            }
          ],
          { session }
        ).then(arr => arr[0]);
      }

      // Mark transaction as SETTLED & SUCCESS
      lockedTxn.walletSettlementStatus = 'SETTLED';
      lockedTxn.walletSettlementAt = new Date();
      lockedTxn.walletDebitLedgerId = ledgerEntry._id;
      lockedTxn.walletFinalizationStatus = 'COMPLETED';
      lockedTxn.reservationStatus = 'CONSUMED';
      lockedTxn.status = 'SUCCESS';
      lockedTxn.completedAt = lockedTxn.completedAt || new Date();
      await lockedTxn.save({ session });

      await session.commitTransaction();
      session.endSession();

      console.log('\n====================================================');
      console.log('[WALLET SETTLEMENT SUCCESSFUL]');
      console.log(`orderId: ${orderId}`);
      console.log(`paymentMethod: ${lockedTxn.paymentMethod}`);
      console.log(`grossAmountPaise: ${lockedTxn.grossAmountPaise || (lockedTxn.amount * 100)}`);
      console.log(`commissionAmountPaise: ${lockedTxn.commissionAmountPaise || (lockedTxn.commissionAmount * 100)}`);
      console.log(`netPayablePaise: ${netDebitPaise}`);
      console.log(`walletBalanceBeforePaise: ${walletBalanceBeforePaise}`);
      console.log(`holdBeforePaise: ${holdBeforePaise}`);
      console.log(`availableBeforePaise: ${availableBeforePaise}`);
      console.log(`walletBalanceAfterPaise: ${walletBalanceAfterPaise}`);
      console.log(`holdAfterPaise: ${holdAfterPaise}`);
      console.log(`availableAfterPaise: ${availableAfterPaise}`);
      console.log('====================================================\n');

      return {
        success: true,
        alreadySettled: false,
        walletBalanceAfterPaise,
        holdAfterPaise,
        availableAfterPaise,
      };
    } catch (error) {
      await session.abortTransaction();
      session.endSession();

      if (error.message.includes('Transaction') || error.message.includes('replica set')) {
        console.warn('[WALLET SETTLEMENT] Replica set transaction error, attempting standalone atomic fallback...');
        return await this._settleWalletOrderAtomic({ userId, orderId, netPayablePaise: netDebitPaise });
      }

      throw error;
    }
  }

  async _settleWalletOrderAtomic({ userId, orderId, netPayablePaise }) {
    const lockedTxn = await RechargeTransaction.findOneAndUpdate(
      {
        orderId,
        walletSettlementStatus: { $ne: 'SETTLED' }
      },
      {
        $set: { walletSettlementStatus: 'PENDING' }
      },
      { new: true }
    );

    if (!lockedTxn) {
      return { success: true, alreadySettled: true };
    }

    const netDebitPaise = Math.round(Number(netPayablePaise || lockedTxn.netPayablePaise || (lockedTxn.payableAmount * 100)) || 0);

    const walletBefore = await Wallet.findOne({ userId }).lean();
    if (!walletBefore) {
      throw new Error(`Wallet not found for userId ${userId}`);
    }

    const walletBalanceBeforePaise = Math.round(walletBefore.balancePaise || 0);
    const holdBeforePaise = Math.round(walletBefore.onHoldPaise || 0);
    const holdToReleasePaise = Math.min(holdBeforePaise, netDebitPaise);

    await Wallet.updateOne(
      { userId },
      {
        $inc: {
          balancePaise: -netDebitPaise,
          onHoldPaise: -holdToReleasePaise,
        }
      }
    );

    const walletAfterDoc = await Wallet.findOne({ userId }).lean();
    const walletBalanceAfterPaise = Math.round(walletAfterDoc.balancePaise || 0);

    let ledgerEntry = await WalletLedger.findOne({
      userId,
      referenceType: 'RECHARGE',
      referenceId: lockedTxn._id,
      transactionType: 'DEBIT'
    });

    if (!ledgerEntry) {
      ledgerEntry = await WalletLedger.create({
        userId,
        transactionType: 'DEBIT',
        amountPaise: netDebitPaise,
        previousBalancePaise: walletBalanceBeforePaise,
        balanceAfterPaise: walletBalanceAfterPaise,
        amount: Number((netDebitPaise / 100).toFixed(2)),
        previousBalance: Number((walletBalanceBeforePaise / 100).toFixed(2)),
        balanceAfter: Number((walletBalanceAfterPaise / 100).toFixed(2)),
        referenceType: 'RECHARGE',
        referenceId: lockedTxn._id,
        description: `Recharge for ${lockedTxn.mobileNumber} - Order ID: ${lockedTxn.orderId}`,
        remark: 'NET_PAYABLE_DEBIT',
      });
    }

    lockedTxn.walletSettlementStatus = 'SETTLED';
    lockedTxn.walletSettlementAt = new Date();
    lockedTxn.walletDebitLedgerId = ledgerEntry._id;
    lockedTxn.walletFinalizationStatus = 'COMPLETED';
    lockedTxn.reservationStatus = 'CONSUMED';
    lockedTxn.status = 'SUCCESS';
    lockedTxn.completedAt = lockedTxn.completedAt || new Date();
    await lockedTxn.save();

    return {
      success: true,
      alreadySettled: false,
      walletBalanceAfterPaise,
      holdAfterPaise: walletAfterDoc.onHoldPaise,
      availableAfterPaise: Math.max(0, walletBalanceAfterPaise - walletAfterDoc.onHoldPaise),
    };
  }

  /**
   * Releases a reserved hold on FAILED or CANCELLED recharge.
   * Permanent balance is UNTOUCHED (0 debit).
   */
  async releaseOrderHold({ userId, orderId, netPayablePaise }) {
    const txn = await RechargeTransaction.findOne({ orderId });
    if (!txn) return true;

    if (txn.walletSettlementStatus === 'SETTLED') {
      console.warn(`[WALLET RELEASE WARNING] Order ${orderId} is ALREADY SETTLED. Will not release hold.`);
      return true;
    }

    if (txn.walletSettlementStatus === 'RELEASED' || txn.reservationStatus === 'RELEASED') {
      console.log(`[WALLET RELEASE IDEMPOTENT] Order ${orderId} hold ALREADY RELEASED.`);
      return true;
    }

    const releasePaise = Math.round(Number(netPayablePaise || txn.reservedAmountPaise || txn.netPayablePaise || (txn.payableAmount * 100)) || 0);

    const walletDoc = await Wallet.findOne({ userId }).lean();
    if (walletDoc && releasePaise > 0) {
      const currentHold = Math.round(walletDoc.onHoldPaise || 0);
      const actualRelease = Math.min(currentHold, releasePaise);

      if (actualRelease > 0) {
        await Wallet.updateOne(
          { userId },
          { $inc: { onHoldPaise: -actualRelease } }
        );
      }
    }

    txn.walletSettlementStatus = 'RELEASED';
    txn.reservationStatus = 'RELEASED';
    await txn.save();

    console.log(`[WALLET HOLD RELEASED] orderId=${orderId} userId=${userId} releasedPaise=${releasePaise}`);
    return true;
  }

  /**
   * Backwards compatible reserve / commit / release helpers
   */
  async reserveAmount(userId, amount) {
    const netPayablePaise = Math.round(Number(amount) * 100);
    return await this.reserveWalletAmount({ userId, netPayablePaise, orderId: null });
  }

  async commitReservation(userId, amount) {
    const netDebitPaise = Math.round(Number(amount) * 100);
    const txn = await RechargeTransaction.findOne({ userId, status: { $in: ['SUCCESS', 'PROCESSING', 'PENDING'] } }).sort({ createdAt: -1 });
    if (txn) {
      return await this.settleWalletOrder({ userId, orderId: txn.orderId, netPayablePaise: netDebitPaise });
    }
    return { success: true };
  }

  async commitOrderReservation(options) {
    const { userId, orderId, amount } = options;
    const netDebitPaise = Math.round(Number(amount) * 100);
    return await this.settleWalletOrder({ userId, orderId, netPayablePaise: netDebitPaise });
  }

  async releaseReservation(userId, amount) {
    const releasePaise = Math.round(Number(amount) * 100);
    const walletDoc = await Wallet.findOne({ userId }).lean();
    if (!walletDoc) return true;
    const currentHold = Math.round(walletDoc.onHoldPaise || 0);
    const actualRelease = Math.min(currentHold, releasePaise);
    if (actualRelease > 0) {
      await Wallet.updateOne({ userId }, { $inc: { onHoldPaise: -actualRelease } });
    }
    return true;
  }

  async addBalance(userId, amount) {
    const amountPaise = Math.round(Number(amount) * 100);
    const result = await Wallet.updateOne(
      { userId },
      { $inc: { balancePaise: amountPaise } }
    );
    return result.modifiedCount > 0;
  }
}

module.exports = new WalletService();
