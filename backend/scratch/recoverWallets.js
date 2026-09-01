const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);

    const users = await mongoose.connection.db.collection('users').find({}).toArray();
    console.log(`\nFound ${users.length} users in system:`);

    const walletsCol = mongoose.connection.db.collection('wallets');
    const ledgersCol = mongoose.connection.db.collection('walletledgers');

    for (const user of users) {
      // Find audit logs or notifications for this user
      const userAudits = await mongoose.connection.db.collection('auditlogs').find({
        $or: [
          { adminId: user._id },
          { resourceId: user._id },
          { 'oldValue.userId': user._id },
          { 'newValue.userId': user._id },
        ]
      }).sort({ createdAt: -1 }).toArray();

      const userNotifs = await mongoose.connection.db.collection('notifications').find({
        userId: user._id
      }).sort({ createdAt: -1 }).toArray();

      console.log(`\n----------------------------------------------------`);
      console.log(`User ID: ${user._id} | Phone: ${user.phone} | Name: ${user.name} | Role: ${user.role}`);
      console.log(`Audit logs count: ${userAudits.length} | Notifications count: ${userNotifs.length}`);

      // Check last balance from audit logs
      let lastKnownBalancePaise = 0;
      for (const a of userAudits) {
        if (a.oldValue && typeof a.oldValue.balancePaise === 'number') {
          lastKnownBalancePaise = a.oldValue.balancePaise;
          console.log(`  Found last known balance in audit log: ${lastKnownBalancePaise} paise (₹${lastKnownBalancePaise / 100})`);
          break;
        }
        if (a.newValue && typeof a.newValue.balancePaise === 'number') {
          lastKnownBalancePaise = a.newValue.balancePaise;
          console.log(`  Found last known balance in audit log: ${lastKnownBalancePaise} paise (₹${lastKnownBalancePaise / 100})`);
          break;
        }
      }

      // Upsert wallet record
      let existingWallet = await walletsCol.findOne({ userId: user._id });
      if (!existingWallet) {
        await walletsCol.insertOne({
          userId: user._id,
          balancePaise: lastKnownBalancePaise,
          onHoldPaise: 0,
          currency: 'INR',
          createdAt: new Date(),
          updatedAt: new Date(),
        });
        console.log(`  [RESTORED WALLET] userId: ${user._id} balancePaise: ${lastKnownBalancePaise}`);
      } else {
        await walletsCol.updateOne(
          { userId: user._id },
          { $set: { balancePaise: Math.max(existingWallet.balancePaise || 0, lastKnownBalancePaise) } }
        );
        console.log(`  [UPDATED WALLET] userId: ${user._id} balancePaise: ${Math.max(existingWallet.balancePaise || 0, lastKnownBalancePaise)}`);
      }

      // Check if wallet ledger exists
      let existingLedger = await ledgersCol.findOne({ userId: user._id });
      if (!existingLedger) {
        await ledgersCol.insertOne({
          userId: user._id,
          transactionType: 'CREDIT',
          amountPaise: lastKnownBalancePaise,
          previousBalancePaise: 0,
          balanceAfterPaise: lastKnownBalancePaise,
          amount: Number((lastKnownBalancePaise / 100).toFixed(2)),
          previousBalance: 0,
          balanceAfter: Number((lastKnownBalancePaise / 100).toFixed(2)),
          referenceType: 'MANUAL',
          referenceId: `RESTORE_${user._id}_${Date.now()}`,
          remark: 'ACCOUNT_BALANCE_RESTORED',
          description: 'Initial balance restoration from system audit logs',
          createdAt: new Date(),
          updatedAt: new Date(),
        });
        console.log(`  [RESTORED LEDGER] userId: ${user._id} amount: ${lastKnownBalancePaise / 100}`);
      }
    }

    console.log('\n====================================================');
    console.log('ALL USER WALLETS AND LEDGERS RESTORED');
    console.log('====================================================\n');

  } catch (e) {
    console.error('Recovery error:', e);
  } finally {
    await mongoose.disconnect();
  }
})();
