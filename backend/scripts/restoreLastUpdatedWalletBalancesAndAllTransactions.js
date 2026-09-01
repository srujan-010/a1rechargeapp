const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function restoreLastUpdatedBalancesAndAllTransactions() {
  const prodMongoUri = process.env.MONGODB_URI;
  console.log('\n====================================================');
  console.log('[FULL RESTORATION OF LAST UPDATED WALLET BALANCES & LEDGERS]');
  console.log(`Database: ${prodMongoUri ? prodMongoUri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@') : 'NONE'}`);
  console.log('====================================================\n');

  await mongoose.connect(prodMongoUri);
  const db = mongoose.connection.db;

  const users = await db.collection('users').find({}).toArray();
  const notifsCol = db.collection('notifications');
  const auditCol = db.collection('auditlogs');
  const walletsCol = db.collection('wallets');
  const ledgersCol = db.collection('walletledgers');

  console.log(`Processing ${users.length} users...\n`);

  for (const u of users) {
    const uId = u._id;
    const uIdStr = String(u._id);

    // Get all notifications sorted chronologically
    const uNotifs = await notifsCol.find({ userId: uId }).sort({ createdAt: 1 }).toArray();
    const uAudits = await auditCol.find({ $or: [{ adminId: uId }, { resourceId: uId }] }).sort({ createdAt: 1 }).toArray();

    console.log(`----------------------------------------------------`);
    console.log(`Retailer: ${u.name} (${u.phone}) | ID: ${uIdStr}`);
    console.log(`Notifications: ${uNotifs.length} | Audit Logs: ${uAudits.length}`);

    let lastUpdatedBalPaise = 0;
    let foundLastBalInNotifs = false;

    // Scan notifications backwards to find the last updated balance text
    for (let i = uNotifs.length - 1; i >= 0; i--) {
      const n = uNotifs[i];
      const msg = n.message || '';

      // Pattern 1: New Balance: ₹1477.19 or ₹776.38 or New Balance: ₹.
      const matchNewBal = msg.match(/New Balance:\s*₹\s*([\d.]+)/i);
      if (matchNewBal && parseFloat(matchNewBal[1]) > 0) {
        lastUpdatedBalPaise = Math.round(parseFloat(matchNewBal[1]) * 100);
        foundLastBalInNotifs = true;
        console.log(`  Found last updated balance in notification [${n.createdAt ? new Date(n.createdAt).toISOString() : 'N/A'}]: ₹${matchNewBal[1]} (${lastUpdatedBalPaise}p)`);
        break;
      }
    }

    // If not found in notification text, check audit logs
    if (!foundLastBalInNotifs) {
      for (let i = uAudits.length - 1; i >= 0; i--) {
        const a = uAudits[i];
        if (a.newValue && typeof a.newValue.balancePaise === 'number') {
          lastUpdatedBalPaise = a.newValue.balancePaise;
          console.log(`  Found last updated balance in audit log: ₹${(lastUpdatedBalPaise/100).toFixed(2)} (${lastUpdatedBalPaise}p)`);
          break;
        }
        if (a.oldValue && typeof a.oldValue.balancePaise === 'number') {
          lastUpdatedBalPaise = a.oldValue.balancePaise;
          console.log(`  Found last updated balance in audit log: ₹${(lastUpdatedBalPaise/100).toFixed(2)} (${lastUpdatedBalPaise}p)`);
          break;
        }
      }
    }

    // Check existing stored wallet
    const currentW = await walletsCol.findOne({ userId: uId });
    if (currentW && currentW.balancePaise > 0) {
      lastUpdatedBalPaise = Math.max(lastUpdatedBalPaise, currentW.balancePaise);
    }

    // Restore Wallet Document
    await walletsCol.updateOne(
      { userId: uId },
      {
        $set: {
          balancePaise: lastUpdatedBalPaise,
          onHoldPaise: 0,
          currency: 'INR',
          updatedAt: new Date(),
        }
      },
      { upsert: true }
    );

    console.log(`  => RESTORED WALLET BALANCE: ₹${(lastUpdatedBalPaise/100).toFixed(2)} (${lastUpdatedBalPaise} paise)`);

    // Reconstruct Ledger Entries from Notifications for Complete Statement History
    let ledgersRestored = 0;
    let cumulativeBal = 0;

    for (const n of uNotifs) {
      const title = n.title || '';
      const msg = n.message || '';
      const createdAt = n.createdAt || new Date();
      const refId = String(n._id);

      const existingL = await ledgersCol.findOne({ userId: uId, referenceId: refId });
      if (!existingL) {
        if (title.includes('Wallet Credited') || msg.includes('added to your') || msg.includes('credited to your wallet')) {
          const matchAmt = msg.match(/₹\s*([\d.]+)/);
          if (matchAmt) {
            const amtR = parseFloat(matchAmt[1]);
            const amtP = Math.round(amtR * 100);
            if (amtP > 0) {
              const prevBal = cumulativeBal;
              cumulativeBal += amtP;
              await ledgersCol.insertOne({
                userId: uId,
                transactionType: 'CREDIT',
                amountPaise: amtP,
                previousBalancePaise: prevBal,
                balanceAfterPaise: cumulativeBal,
                amount: amtR,
                previousBalance: Number((prevBal / 100).toFixed(2)),
                balanceAfter: Number((cumulativeBal / 100).toFixed(2)),
                referenceType: 'ADD_MONEY',
                referenceId: refId,
                remark: title,
                description: msg,
                createdAt,
                updatedAt: createdAt,
              });
              ledgersRestored++;
            }
          }
        } else if (title.includes('Wallet Debited') || msg.includes('was debited from your wallet')) {
          const matchAmt = msg.match(/₹\s*([\d.]+)/);
          if (matchAmt) {
            const amtR = parseFloat(matchAmt[1]);
            const amtP = Math.round(amtR * 100);
            if (amtP > 0) {
              const prevBal = cumulativeBal;
              cumulativeBal = Math.max(0, cumulativeBal - amtP);
              await ledgersCol.insertOne({
                userId: uId,
                transactionType: 'DEBIT',
                amountPaise: amtP,
                previousBalancePaise: prevBal,
                balanceAfterPaise: cumulativeBal,
                amount: amtR,
                previousBalance: Number((prevBal / 100).toFixed(2)),
                balanceAfter: Number((cumulativeBal / 100).toFixed(2)),
                referenceType: 'RECHARGE',
                referenceId: refId,
                remark: title,
                description: msg,
                createdAt,
                updatedAt: createdAt,
              });
              ledgersRestored++;
            }
          }
        }
      }
    }

    console.log(`  => RESTORED LEDGERS COUNT: ${ledgersRestored}\n`);
  }

  console.log('====================================================');
  console.log('[ALL WALLET BALANCES & STATEMENT LEDGERS FULLY RESTORED]');
  console.log('====================================================\n');

  await mongoose.disconnect();
}

if (require.main === module) {
  restoreLastUpdatedBalancesAndAllTransactions().catch(err => {
    console.error('Bal & Ledger Restore Error:', err);
    process.exit(1);
  });
}

module.exports = { restoreLastUpdatedBalancesAndAllTransactions };
