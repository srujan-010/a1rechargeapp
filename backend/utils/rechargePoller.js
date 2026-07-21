const RechargeTransaction = require('../models/RechargeTransaction');
const pendingRechargeWorker = require('../workers/pendingRecharge.worker');

/**
 * Asynchronous fast poller for PENDING recharges
 * It will check status after 5s, 10s, and 20s.
 */
const startPolling = async (orderId) => {
  // Polling intervals in milliseconds
  const delays = [5000, 10000, 20000];

  for (const delay of delays) {
    // Wait for the next interval
    await new Promise(resolve => setTimeout(resolve, delay));
    
    try {
      // 1. Fetch transaction
      const transaction = await RechargeTransaction.findOne({ orderId });
      
      // 2. If it's already resolved (by webhook or manual check), stop polling
      if (!transaction || transaction.status !== 'PENDING') {
        console.log(`[Poller] Transaction ${orderId} is no longer PENDING. Stopping poll.`);
        return; 
      }
      
      console.log(`[Poller] Checking status for ${orderId}...`);
      
      // 3. Reuse worker logic to query provider and update DB
      await pendingRechargeWorker.processTransaction(transaction);
      
      // 4. Fetch updated transaction to see if it resolved
      const updatedTx = await RechargeTransaction.findOne({ orderId });
      if (updatedTx && updatedTx.status !== 'PENDING') {
        console.log(`[Poller] Transaction ${orderId} resolved to ${updatedTx.status}. Stopping poll.`);
        return; // Resolved, exit polling loop
      }
    } catch (e) {
      console.error(`[Poller] Error for ${orderId}:`, e.message);
    }
  }
  
  console.log(`[Poller] Exhausted fast polling for ${orderId}. Will rely on cron/webhooks.`);
};

module.exports = { startPolling };
