const mongoose = require('mongoose');
const Wallet = require('../../models/Wallet');
const WalletLedger = require('../../models/WalletLedger');
const RechargeTransaction = require('../../models/RechargeTransaction');
const CommissionHistory = require('../../models/CommissionHistory');
const commissionService = require('../commission/commission.service');

class WalletService {
  /**
   * Financial integrity assertion helper.
   * Ensures money is an integer paise value.
   */
  _assertIntegerPaise(amountPaise, name = 'Amount', orderId = null) {
    const num = Number(amountPaise);
    if (!Number.isInteger(num) || isNaN(num)) {
      const errorMsg = `[FINANCIAL INTEGRITY ERROR] ${name} must be an integer paise value. Received: ${amountPaise} (orderId: ${orderId || 'N/A'})`;
      console.error(errorMsg);
      throw new Error(errorMsg);
    }
    return num;
  }

  /**
   * Fetches full wallet balance object for a given user in Integer Paise.
   */
  async getWalletBalancePaise(userId) {
    let wallet = await Wallet.findOne({ userId }).lean();
    if (!wallet) {
      wallet = await Wallet.create({ userId, balancePaise: 0, onHoldPaise: 0, currency: 'INR' });
    }
    const balancePaise = this._assertIntegerPaise(wallet.balancePaise || 0, 'balancePaise');
    const holdAmountPaise = this._assertIntegerPaise(wallet.onHoldPaise || 0, 'onHoldPaise');
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
   * NON-WALLET transactions (e.g. RAZORPAY_UPI) DO NOT MODIFY WALLET.
   */
  async reserveWalletAmount({ userId, netPayablePaise, orderId, paymentMethod }) {
    const netPaise = this._assertIntegerPaise(netPayablePaise, 'netPayablePaise', orderId);

    if (netPaise <= 0) {
      throw new Error(`Invalid reservation net payable amount paise: ${netPayablePaise}`);
    }

    // Load transaction if orderId provided to check paymentMethod
    let txn = null;
    if (orderId) {
      txn = await RechargeTransaction.findOne({ orderId }).lean();
    }

    const effectiveMethod = (paymentMethod || txn?.paymentMethod || 'WALLET').toUpperCase();
    if (effectiveMethod !== 'WALLET') {
      console.log(`[WALLET RESERVATION SKIPPED] orderId=${orderId} paymentMethod=${effectiveMethod} is NOT WALLET. Zero wallet hold.`);
      if (orderId) {
        await RechargeTransaction.updateOne(
          { orderId },
          {
            $set: {
              reservedAmountPaise: 0,
              reservedAmount: 0,
              reservationStatus: 'NONE',
              walletSettlementStatus: 'NONE',
            }
          }
        );
      }
      return true;
    }

    const session = await mongoose.startSession();
    try {
      session.startTransaction();

      let wallet = await Wallet.findOne({ userId }).session(session);
      if (!wallet) {
        throw new Error('Wallet not found for user');
      }

      const balancePaise = this._assertIntegerPaise(wallet.balancePaise || 0, 'balancePaise');
      const holdPaise = this._assertIntegerPaise(wallet.onHoldPaise || 0, 'onHoldPaise');
      const available = Math.max(0, balancePaise - holdPaise);

      if (available < netPaise) {
        const shortfallPaise = netPaise - available;
        const err = new Error(`Insufficient wallet balance. Shortfall: ₹${(shortfallPaise / 100).toFixed(2)}`);
        err.shortfallPaise = shortfallPaise;
        err.availablePaise = available;
        err.netPayablePaise = netPaise;
        throw err;
      }

      wallet.onHoldPaise = holdPaise + netPaise;
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

      if (error.message && (error.message.includes('Transaction') || error.message.includes('replica set'))) {
        console.warn('[WALLET RESERVATION] Falling back to atomic updateOne...');
        return await this._reserveWalletAmountAtomic({ userId, netPayablePaise: netPaise, orderId, paymentMethod: effectiveMethod });
      }

      throw error;
    }
  }

  async _reserveWalletAmountAtomic({ userId, netPayablePaise, orderId, paymentMethod }) {
    const netPaise = this._assertIntegerPaise(netPayablePaise, 'netPayablePaise', orderId);

    const effectiveMethod = (paymentMethod || 'WALLET').toUpperCase();
    if (effectiveMethod !== 'WALLET') {
      return true;
    }

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
   * CRITICAL: RAZORPAY_UPI transactions produce ZERO wallet debit.
   */
  async settleWalletOrder({ userId, orderId, netPayablePaise }) {
    if (!orderId) {
      throw new Error('orderId is required for wallet settlement');
    }

    // 1. Load transaction
    const txn = await RechargeTransaction.findOne({ orderId });
    if (!txn) {
      throw new Error(`RechargeTransaction not found for orderId ${orderId}`);
    }

    const methodUpper = (txn.paymentMethod || 'WALLET').toUpperCase();

    // 2. CRITICAL PAYMENT METHOD SEPARATION: NON-WALLET (e.g. RAZORPAY_UPI) MUST NEVER DEBIT WALLET
    if (methodUpper !== 'WALLET') {
      console.log(`\n====================================================`);
      console.log(`[UPI SETTLEMENT - NO WALLET MUTATION]`);
      console.log(`orderId: ${orderId}`);
      console.log(`paymentMethod: ${txn.paymentMethod}`);
      console.log(`grossAmountPaise: ${txn.grossAmountPaise || Math.round((txn.amount || 0) * 100)}`);
      console.log(`commissionAmountPaise: ${txn.commissionAmountPaise || Math.round((txn.commissionAmount || 0) * 100)}`);
      console.log(`walletDebit: 0`);
      console.log(`====================================================\n`);

      // Atomically mark transaction as final without modifying wallet
      await RechargeTransaction.updateOne(
        { orderId },
        {
          $set: {
            walletSettlementStatus: 'NONE',
            walletFinalizationStatus: 'COMPLETED',
            reservationStatus: 'NONE',
            status: 'SUCCESS',
            completedAt: txn.completedAt || new Date(),
          }
        }
      );

      const currentWallet = await Wallet.findOne({ userId }).lean();
      return {
        success: true,
        isUpi: true,
        alreadySettled: true,
        walletBalanceAfterPaise: currentWallet ? Math.round(currentWallet.balancePaise || 0) : 0,
        holdAfterPaise: currentWallet ? Math.round(currentWallet.onHoldPaise || 0) : 0,
        availableAfterPaise: currentWallet ? Math.max(0, (currentWallet.balancePaise || 0) - (currentWallet.onHoldPaise || 0)) : 0,
      };
    }

    // 3. Idempotency Check: Verify if order is already settled
    if (txn.walletSettlementStatus === 'SETTLED' || txn.walletFinalizationStatus === 'COMPLETED') {
      console.log(`[WALLET SETTLEMENT IDEMPOTENT] orderId=${orderId} is ALREADY SETTLED. Skipping duplicate settlement.`);
      return { success: true, alreadySettled: true };
    }

    const netDebitPaise = this._assertIntegerPaise(
      netPayablePaise != null ? netPayablePaise : (txn.netPayablePaise || Math.round((txn.payableAmount || txn.amount) * 100)),
      'netPayablePaise',
      orderId
    );

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

      const walletBalanceBeforePaise = this._assertIntegerPaise(wallet.balancePaise || 0, 'walletBalanceBeforePaise', orderId);
      const holdBeforePaise = this._assertIntegerPaise(wallet.onHoldPaise || 0, 'holdBeforePaise', orderId);
      const availableBeforePaise = Math.max(0, walletBalanceBeforePaise - holdBeforePaise);

      // Hold reduction is capped by current onHoldPaise to prevent negative hold
      const holdToReleasePaise = Math.min(holdBeforePaise, netDebitPaise);

      wallet.balancePaise = walletBalanceBeforePaise - netDebitPaise;
      wallet.onHoldPaise = holdBeforePaise - holdToReleasePaise;
      await wallet.save({ session });

      const walletBalanceAfterPaise = wallet.balancePaise;
      const holdAfterPaise = wallet.onHoldPaise;
      const availableAfterPaise = Math.max(0, walletBalanceAfterPaise - holdAfterPaise);

      // Create EXACTLY ONE WalletLedger Entry (DB unique index enforces idempotency)
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
      console.log('[WALLET_SETTLEMENT_SUCCESS]');
      console.log(`orderId: ${orderId}`);
      console.log(`paymentMethod: ${lockedTxn.paymentMethod}`);
      console.log(`grossAmountPaise: ${lockedTxn.grossAmountPaise || Math.round((lockedTxn.amount || 0) * 100)}`);
      console.log(`commissionAmountPaise: ${lockedTxn.commissionAmountPaise || Math.round((lockedTxn.commissionAmount || 0) * 100)}`);
      console.log(`netDebitPaise: ${netDebitPaise}`);
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

      if (error.code === 112 || (error.message && (error.message.includes('Transaction') || error.message.includes('replica set') || error.message.includes('retryable') || error.message.includes('MongoServerError') || error.message.includes('Write conflict') || error.message.includes('WriteConflict')))) {
        console.warn('[WALLET SETTLEMENT] Concurrency/Standalone fallback attempting atomic execution...');
        return await this._settleWalletOrderAtomic({ userId, orderId, netPayablePaise: netDebitPaise });
      }

      throw error;
    }
  }

  async _settleWalletOrderAtomic({ userId, orderId, netPayablePaise }) {
    const txn = await RechargeTransaction.findOne({ orderId }).lean();
    if (txn && (txn.paymentMethod || '').toUpperCase() !== 'WALLET') {
      return { success: true, isUpi: true, alreadySettled: true };
    }

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

    const netDebitPaise = this._assertIntegerPaise(
      netPayablePaise != null ? netPayablePaise : (lockedTxn.netPayablePaise || Math.round((lockedTxn.payableAmount || lockedTxn.amount) * 100)),
      'netPayablePaise',
      orderId
    );

    const walletBefore = await Wallet.findOne({ userId }).lean();
    if (!walletBefore) {
      throw new Error(`Wallet not found for userId ${userId}`);
    }

    const walletBalanceBeforePaise = this._assertIntegerPaise(walletBefore.balancePaise || 0, 'walletBalanceBeforePaise', orderId);
    const holdBeforePaise = this._assertIntegerPaise(walletBefore.onHoldPaise || 0, 'holdBeforePaise', orderId);
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
   * NON-WALLET transactions do nothing.
   */
  async releaseOrderHold({ userId, orderId, netPayablePaise }) {
    const txn = await RechargeTransaction.findOne({ orderId });
    if (!txn) return true;

    const methodUpper = (txn.paymentMethod || 'WALLET').toUpperCase();
    if (methodUpper !== 'WALLET') {
      console.log(`[WALLET HOLD RELEASE SKIPPED] orderId=${orderId} paymentMethod=${methodUpper} is NOT WALLET.`);
      txn.walletSettlementStatus = 'NONE';
      txn.reservationStatus = 'NONE';
      await txn.save();
      return true;
    }

    if (txn.walletSettlementStatus === 'SETTLED') {
      console.warn(`[WALLET RELEASE WARNING] Order ${orderId} is ALREADY SETTLED. Will not release hold.`);
      return true;
    }

    if (txn.walletSettlementStatus === 'RELEASED' || txn.reservationStatus === 'RELEASED') {
      console.log(`[WALLET RELEASE IDEMPOTENT] Order ${orderId} hold ALREADY RELEASED.`);
      return true;
    }

    const releasePaise = this._assertIntegerPaise(
      netPayablePaise != null ? netPayablePaise : (txn.reservedAmountPaise || txn.netPayablePaise || Math.round((txn.payableAmount || txn.amount) * 100)),
      'netPayablePaise',
      orderId
    );

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
    return await this.reserveWalletAmount({ userId, netPayablePaise, orderId: null, paymentMethod: 'WALLET' });
  }

  async commitReservation(userId, amount) {
    const netDebitPaise = Math.round(Number(amount) * 100);
    const txn = await RechargeTransaction.findOne({ userId, paymentMethod: { $in: ['WALLET', 'wallet'] }, status: { $in: ['SUCCESS', 'PROCESSING', 'PENDING'] } }).sort({ createdAt: -1 });
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

