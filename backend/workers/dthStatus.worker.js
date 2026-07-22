const RechargeTransaction = require('../models/RechargeTransaction');
const dthStatusService = require('../services/dthStatus.service');

let isRunning = false;
let timerId = null;

/**
 * Dedicated Background Worker for DTH Pending Status Sync
 */
class DthStatusWorker {
  /**
   * Processes all pending DTH transactions in MongoDB.
   */
  async processPendingDth() {
    if (isRunning) {
      console.log('[DTH Worker] Previous execution still running, skipping tick.');
      return;
    }

    isRunning = true;

    try {
      // 1. Query pending DTH transactions
      const pendingTxns = await RechargeTransaction.find({
        serviceType: 'dth',
        status: 'PENDING'
      }).limit(20);

      if (pendingTxns.length === 0) {
        isRunning = false;
        return;
      }

      console.log(`[DTH Worker] Found ${pendingTxns.length} pending DTH transaction(s) to verify.`);

      for (const txn of pendingTxns) {
        console.log(`[DTH Worker] Processing Pending DTH Transaction: Order ID=${txn.orderId}, Mongo ID=${txn._id}`);
        try {
          await dthStatusService.checkDthStatus(txn.orderId);
        } catch (err) {
          console.error(`[DTH Worker] Error checking order ${txn.orderId}:`, err.message);
        }
      }
    } catch (error) {
      console.error('[DTH Worker] Execution Error:', error.message);
    } finally {
      isRunning = false;
    }
  }

  /**
   * Starts the background cron/interval worker.
   * @param {number} intervalMs - Poll interval in milliseconds (default: 30 seconds)
   */
  start(intervalMs = 30000) {
    if (timerId) {
      console.log('[DTH Worker] Worker is already running.');
      return;
    }

    console.log(`[DTH Worker] Started polling every ${intervalMs / 1000} seconds.`);
    
    // Initial run
    this.processPendingDth();

    timerId = setInterval(() => {
      this.processPendingDth();
    }, intervalMs);
  }

  /**
   * Stops the background worker.
   */
  stop() {
    if (timerId) {
      clearInterval(timerId);
      timerId = null;
      console.log('[DTH Worker] Worker stopped.');
    }
  }
}

module.exports = new DthStatusWorker();
