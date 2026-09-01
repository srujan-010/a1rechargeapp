const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

async function reconstructDatabase() {
  const mongoUri = process.env.MONGODB_URI;
  if (mongoose.connection.readyState === 0) {
    await mongoose.connect(mongoUri);
  }

  console.log('\n====================================================');
  console.log('[FULL DATABASE RECONSTRUCTION FROM NOTIFICATION AUDIT LOGS]');
  console.log('====================================================\n');

  const notifsCol = mongoose.connection.db.collection('notifications');
  const walletsCol = mongoose.connection.db.collection('wallets');
  const ledgersCol = mongoose.connection.db.collection('walletledgers');
  const rechCol = mongoose.connection.db.collection('rechargetransactions');
  const usersCol = mongoose.connection.db.collection('users');

  const users = await usersCol.find({}).toArray();
  console.log(`Found ${users.length} users to process.\n`);

  for (const user of users) {
    const userIdStr = String(user._id);

    // Fetch all notifications for this user sorted chronologically (oldest to newest)
    const notifs = await notifsCol.find({ userId: user._id }).sort({ createdAt: 1 }).toArray();

    if (notifs.length === 0) {
      continue;
    }

    console.log(`----------------------------------------------------`);
    console.log(`Processing User: ${user.name} (${user.phone}) - ID: ${userIdStr}`);
    console.log(`Total Notifications: ${notifs.length}`);

    let calculatedBalancePaise = 0;
    let ledgerEntriesCreated = 0;
    let rechargeTxnsCreated = 0;

    for (const n of notifs) {
      const title = n.title || '';
      const msg = n.message || '';
      const createdAt = n.createdAt || new Date();
      const relatedOrderId = n.relatedOrderId || `ORDER_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

      // 1. Wallet Topup / Credit
      if (title.includes('Wallet Credited') || msg.includes('has been added to your') || msg.includes('credited to your wallet')) {
        const match = msg.match(/₹\s*([\d.]+)/);
        if (match) {
          const rupees = parseFloat(match[1]);
          const paise = Math.round(rupees * 100);
          if (paise > 0) {
            const prevBalancePaise = calculatedBalancePaise;
            calculatedBalancePaise += paise;

            // Check if ledger entry already exists for this notification
            const existingLedger = await ledgersCol.findOne({
              userId: user._id,
              referenceId: String(n._id),
            });

            if (!existingLedger) {
              await ledgersCol.insertOne({
                userId: user._id,
                transactionType: 'CREDIT',
                amountPaise: paise,
                previousBalancePaise: prevBalancePaise,
                balanceAfterPaise: calculatedBalancePaise,
                amount: rupees,
                previousBalance: Number((prevBalancePaise / 100).toFixed(2)),
                balanceAfter: Number((calculatedBalancePaise / 100).toFixed(2)),
                referenceType: 'ADD_MONEY',
                referenceId: String(n._id),
                remark: title,
                description: msg,
                createdAt,
                updatedAt: createdAt,
              });
              ledgerEntriesCreated++;
            }
          }
        }
      }

      // 2. Wallet Debit
      if (title.includes('Wallet Debited') || msg.includes('was debited from your wallet')) {
        const match = msg.match(/₹\s*([\d.]+)/);
        if (match) {
          const rupees = parseFloat(match[1]);
          const paise = Math.round(rupees * 100);
          if (paise > 0) {
            const prevBalancePaise = calculatedBalancePaise;
            calculatedBalancePaise = Math.max(0, calculatedBalancePaise - paise);

            const existingLedger = await ledgersCol.findOne({
              userId: user._id,
              referenceId: String(n._id),
            });

            if (!existingLedger) {
              await ledgersCol.insertOne({
                userId: user._id,
                transactionType: 'DEBIT',
                amountPaise: paise,
                previousBalancePaise: prevBalancePaise,
                balanceAfterPaise: calculatedBalancePaise,
                amount: rupees,
                previousBalance: Number((prevBalancePaise / 100).toFixed(2)),
                balanceAfter: Number((calculatedBalancePaise / 100).toFixed(2)),
                referenceType: 'RECHARGE',
                referenceId: String(n._id),
                remark: title,
                description: msg,
                createdAt,
                updatedAt: createdAt,
              });
              ledgerEntriesCreated++;
            }
          }
        }
      }

      // 3. Recharge Success / Pending / Failed Creation
      if (title.includes('Recharge Successful') || title.includes('Recharge Failed') || title.includes('Recharge Pending')) {
        const matchAmt = msg.match(/₹\s*([\d.]+)/);
        const amtRupees = matchAmt ? parseFloat(matchAmt[1]) : 0;
        const amtPaise = Math.round(amtRupees * 100);

        const matchPhone = msg.match(/\b\d{10}\b/);
        const mobileNumber = matchPhone ? matchPhone[0] : (user.phone || '9876543210');

        let status = 'SUCCESS';
        if (title.includes('Failed')) status = 'FAILED';
        if (title.includes('Pending')) status = 'PENDING';

        const existingTxn = await rechCol.findOne({ orderId: relatedOrderId });
        if (!existingTxn && amtPaise > 0) {
          await rechCol.insertOne({
            orderId: relatedOrderId,
            userId: user._id,
            providerName: 'A1Topup',
            mobileNumber,
            grossAmountPaise: amtPaise,
            commissionAmountPaise: 0,
            netPayablePaise: amtPaise,
            amount: amtRupees,
            commissionAmount: 0,
            payableAmount: amtRupees,
            operatorCode: 'A',
            circleCode: '1',
            status,
            paymentMethod: 'WALLET',
            walletSettlementStatus: status === 'SUCCESS' ? 'SETTLED' : (status === 'FAILED' ? 'RELEASED' : 'PENDING'),
            completedAt: createdAt,
            createdAt,
            updatedAt: createdAt,
          });
          rechargeTxnsCreated++;
        }
      }
    }

    // Also check last balance snapshot in auditlogs
    const auditSnapshot = await mongoose.connection.db.collection('auditlogs').findOne(
      { $or: [{ adminId: user._id }, { resourceId: user._id }, { 'oldValue.userId': user._id }] },
      { sort: { createdAt: -1 } }
    );

    if (auditSnapshot) {
      if (auditSnapshot.oldValue && typeof auditSnapshot.oldValue.balancePaise === 'number') {
        calculatedBalancePaise = Math.max(calculatedBalancePaise, auditSnapshot.oldValue.balancePaise);
      }
      if (auditSnapshot.newValue && typeof auditSnapshot.newValue.balancePaise === 'number') {
        calculatedBalancePaise = Math.max(calculatedBalancePaise, auditSnapshot.newValue.balancePaise);
      }
    }

    // Update Wallet
    await walletsCol.updateOne(
      { userId: user._id },
      {
        $set: {
          balancePaise: calculatedBalancePaise,
          onHoldPaise: 0,
          currency: 'INR',
          updatedAt: new Date(),
        }
      },
      { upsert: true }
    );

    console.log(`Reconstructed Wallet Balance: ₹${(calculatedBalancePaise / 100).toFixed(2)} (${calculatedBalancePaise} paise)`);
    console.log(`Ledgers Restored: ${ledgerEntriesCreated} | Recharge Txns Restored: ${rechargeTxnsCreated}\n`);
  }

  console.log('====================================================');
  console.log('[DATABASE RECONSTRUCTION COMPLETED SUCCESSFULLY]');
  console.log('====================================================\n');
}

if (require.main === module) {
  reconstructDatabase().then(() => mongoose.disconnect()).catch(err => {
    console.error('Reconstruction Error:', err);
    mongoose.disconnect();
  });
}

module.exports = { reconstructDatabase };
