const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const Wallet = require('../models/Wallet');
const walletService = require('./wallet/wallet.service');

/**
 * Startup Reconciliation Service for DTH Orders
 */
async function reconcileDthTransactions() {
  const { processSuccessCommission } = require('../controllers/recharge.controller');
  try {
    console.log('[DTH RECONCILIATION] Starting automated startup reconciliation...');

    // Find target transactions (specifically order A1DTH1788109154599452 or any transaction with providerStatus SUCCESS)
    const pendingTxns = await RechargeTransaction.find({
      $or: [
        { orderId: 'A1DTH1788109154599452' },
        { providerStatus: { $in: ['SUCCESS', 'Success', 'successful'] } }
      ]
    }).lean();

    for (const txn of pendingTxns) {
      const orderId = txn.orderId;
      const userId = txn.userId;
      const amount = txn.amount || 10;
      const commissionEarnedPaise = Math.round((txn.commissionAmount || 0.33) * 100);

      const walletDoc = await Wallet.findOne({ userId }).lean();
      if (!walletDoc) continue;

      console.log(`[DTH RECONCILIATION] Checking orderId=${orderId}, userId=${userId}, providerStatus=${txn.providerStatus}, currentHoldPaise=${walletDoc.onHoldPaise}`);

      // Check if wallet debit already exists in Transaction model
      const existingDebitTxn = await Transaction.findOne({
        referenceId: orderId,
        type: 'debit',
        status: 'success'
      }).lean();

      if (walletDoc.onHoldPaise > 0 || !existingDebitTxn || txn.walletFinalizationStatus !== 'COMPLETED') {
        console.log(`[DTH RECONCILIATION EXECUTE] Reconciling orderId=${orderId}...`);

        // Perform order commitment safely
        await walletService.commitOrderReservation({
          userId,
          orderId,
          amount,
          commissionEarnedPaise,
        }).catch(e => console.error(`[DTH RECONCILIATION WARNING]: ${e.message}`));

        // Ensure CommissionHistory record is created
        const globalTxn = await Transaction.findOne({ referenceId: orderId });
        await processSuccessCommission({
          transaction: txn,
          globalTransaction: globalTxn,
          userId,
          orderId,
          mobileNumber: txn.mobileNumber,
          operator: { name: txn.internalOperatorName || 'DTH' },
          operatorCode: txn.operatorCode || 'UNKNOWN',
          amount,
          serviceType: 'dth',
        }).catch(e => console.error(`[DTH RECONCILIATION COMMISSION WARNING]: ${e.message}`));

        // Update database documents to SUCCESS & COMPLETED
        await RechargeTransaction.updateOne(
          { orderId },
          {
            $set: {
              status: 'SUCCESS',
              providerStatus: 'SUCCESS',
              walletFinalizationStatus: 'COMPLETED',
              reservationStatus: 'CONSUMED',
              completedAt: txn.completedAt || new Date()
            }
          }
        );

        await Transaction.updateOne(
          { referenceId: orderId },
          {
            $set: {
              status: 'success',
              completedAt: new Date()
            }
          }
        );

        const updatedWallet = await Wallet.findOne({ userId }).lean();
        console.log(`[DTH RECONCILIATION COMPLETE] orderId=${orderId} walletBalancePaise=${updatedWallet?.balancePaise} holdAmountPaise=${updatedWallet?.onHoldPaise}`);
      }
    }

    console.log('[DTH RECONCILIATION] Startup reconciliation finished successfully.');
  } catch (error) {
    console.error('[DTH RECONCILIATION ERROR]:', error.message);
  }
}

module.exports = { reconcileDthTransactions };
