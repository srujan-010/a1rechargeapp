const autoTimeoutRefundService = require('../services/autoTimeoutRefund.service');

class AutoTimeoutRefundWorker {
  constructor() {
    this.intervalId = null;
    this.isRunning = false;
  }

  start(intervalMs = 2 * 60 * 1000) { // Run every 2 minutes
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }

    console.log(`[Worker] Auto-Timeout Refund Worker started (Interval: ${intervalMs}ms)`);

    // Immediate initial execution on worker startup to clean up any overdue transactions
    setTimeout(() => {
      this.runCycle().catch(err => {
        console.error('[Worker] Initial Auto-Timeout sweep error:', err.message);
      });
    }, 3000);

    this.intervalId = setInterval(() => this.runCycle(), intervalMs);
  }

  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
      console.log('[Worker] Auto-Timeout Refund Worker stopped');
    }
  }

  async runCycle() {
    if (this.isRunning) return; // Prevent overlapping runs
    this.isRunning = true;

    try {
      // 1. Process all timed-out recharges older than 30 minutes
      await autoTimeoutRefundService.processTimedOutRecharges();

      // 2. Retry any pending or failed refunds
      await autoTimeoutRefundService.retryFailedRefunds();
    } catch (err) {
      console.error('[Worker] Auto-Timeout Worker error:', err.message);
    } finally {
      this.isRunning = false;
    }
  }
}

module.exports = new AutoTimeoutRefundWorker();
