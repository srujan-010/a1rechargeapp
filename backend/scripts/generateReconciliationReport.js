const mongoose = require('mongoose');
const path = require('path');

require('dotenv').config({ path: path.join(__dirname, '../.env') });

const User = require('../models/User');
const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');
const RechargeTransaction = require('../models/RechargeTransaction');

async function runDiagnostic() {
  try {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/a1recharge';
    console.log('[DIAGNOSTIC] Connecting to MongoDB:', mongoUri);
    await mongoose.connect(mongoUri);

    console.log('\n====================================================');
    console.log('       CANONICAL FINANCIAL RECONCILIATION REPORT     ');
    console.log('====================================================\n');

    const users = await User.find({}).lean();
    console.log(`Found ${users.length} total user accounts.\n`);

    for (const user of users) {
      const userId = user._id;
      const wallet = await Wallet.findOne({ userId }).lean();

      const storedBalancePaise = wallet ? wallet.balancePaise : 0;
      const storedHoldPaise = wallet ? wallet.onHoldPaise : 0;

      // Fetch all Transactions for ledger reconstruction
      const txns = await Transaction.find({ userId, status: 'success' }).lean();
      
      let calculatedLedgerPaise = 0;
      let totalCreditsPaise = 0;
      let totalDebitsPaise = 0;

      txns.forEach(t => {
        if (t.type === 'credit') {
          totalCreditsPaise += Number(t.amountPaise || 0);
        } else if (t.type === 'debit') {
          totalDebitsPaise += Number(t.amountPaise || 0);
        }
      });

      calculatedLedgerPaise = totalCreditsPaise - totalDebitsPaise;

      // Fetch active holds from in-flight RechargeTransactions
      const activeHolds = await RechargeTransaction.find({
        userId,
        status: { $in: ['PENDING', 'PROCESSING', 'RECHARGE_PROCESSING', 'INITIATED'] }
      }).lean();

      let calculatedHoldPaise = 0;
      activeHolds.forEach(h => {
        const netPaise = h.payableAmount ? Math.round(h.payableAmount * 100) : Math.round((h.amount || 0) * 100);
        calculatedHoldPaise += netPaise;
      });

      const calculatedAvailablePaise = calculatedLedgerPaise - calculatedHoldPaise;
      const storedAvailablePaise = storedBalancePaise - storedHoldPaise;

      console.log(`User: ${user.name} (${user.phone}) | Role: ${user.role} | ID: ${userId}`);
      console.log(`  Stored Balance     : ₹${(storedBalancePaise / 100).toFixed(2)} (${storedBalancePaise} paise)`);
      console.log(`  Stored Hold        : ₹${(storedHoldPaise / 100).toFixed(2)} (${storedHoldPaise} paise)`);
      console.log(`  Stored Available   : ₹${(storedAvailablePaise / 100).toFixed(2)} (${storedAvailablePaise} paise)`);
      console.log(`  Reconstructed Ledger: ₹${(calculatedLedgerPaise / 100).toFixed(2)} (Credits: ₹${(totalCreditsPaise/100).toFixed(2)}, Debits: ₹${(totalDebitsPaise/100).toFixed(2)})`);
      console.log(`  Active In-flight Hold: ₹${(calculatedHoldPaise / 100).toFixed(2)} (${activeHolds.length} pending txns)`);
      console.log(`  Reconstructed Available: ₹${(calculatedAvailablePaise / 100).toFixed(2)}`);
      console.log(`  Balance Discrepancy : ₹${((storedBalancePaise - calculatedLedgerPaise) / 100).toFixed(2)}`);

      // Check order A1DTH1788109154599452 specifically if present
      const specificTxn = await RechargeTransaction.findOne({ orderId: 'A1DTH1788109154599452', userId }).lean();
      if (specificTxn) {
        console.log(`  [ORDER A1DTH1788109154599452]: status=${specificTxn.status}, providerStatus=${specificTxn.providerStatus}, walletFinalizationStatus=${specificTxn.walletFinalizationStatus}`);
      }
      console.log('----------------------------------------------------');
    }

    console.log('\n[DIAGNOSTIC] Finished generating report.');
  } catch (err) {
    console.error('[DIAGNOSTIC ERROR]:', err);
  } finally {
    await mongoose.disconnect();
  }
}

runDiagnostic();
