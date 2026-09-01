const fs = require('fs');
const readline = require('readline');
const mongoose = require('mongoose');
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const transcriptPath = 'C:\\Users\\91789\\.gemini\\antigravity-ide\\brain\\c3c7d937-f263-4682-b7d3-abcd84e555c0\\.system_generated\\logs\\transcript_full.jsonl';

async function scanLogs() {
  const fileStream = fs.createReadStream(transcriptPath);
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  const walletSnapshots = new Map();
  const rechargeTxSnapshots = new Map();

  for await (const line of rl) {
    if (!line) continue;
    try {
      const step = JSON.parse(line);
      const content = step.content || '';
      
      // Look for JSON or log dumps of Wallets
      if (content.includes('balancePaise') || content.includes('balanceRupees') || content.includes('onHoldPaise')) {
        const matches = content.match(/\{[^{}]*balancePaise[^{}]*\}/g);
        if (matches) {
          for (const m of matches) {
            try {
              const obj = JSON.parse(m);
              if (obj.userId && obj.balancePaise != null) {
                walletSnapshots.set(String(obj.userId), obj);
              }
            } catch (e) {}
          }
        }
      }

      // Look for orderId dumps
      if (content.includes('orderId') && content.includes('Recharge')) {
        const matches = content.match(/\{[^{}]*orderId[^{}]*\}/g);
        if (matches) {
          for (const m of matches) {
            try {
              const obj = JSON.parse(m);
              if (obj.orderId && obj.userId) {
                rechargeTxSnapshots.set(String(obj.orderId), obj);
              }
            } catch (e) {}
          }
        }
      }
    } catch (err) {}
  }

  console.log(`\nFound ${walletSnapshots.size} wallet snapshots in transcript logs.`);
  console.log(`Found ${rechargeTxSnapshots.size} recharge transaction snapshots in transcript logs.`);

  for (const [userId, w] of walletSnapshots.entries()) {
    console.log(`Snapshot Wallet: userId=${userId} balancePaise=${w.balancePaise} holdPaise=${w.onHoldPaise}`);
  }

  for (const [orderId, tx] of rechargeTxSnapshots.entries()) {
    console.log(`Snapshot Tx: orderId=${orderId} userId=${tx.userId} amount=${tx.amount} status=${tx.status}`);
  }

  if (walletSnapshots.size > 0 || rechargeTxSnapshots.size > 0) {
    await mongoose.connect(process.env.MONGODB_URI);
    const walletsCol = mongoose.connection.db.collection('wallets');
    const rtxsCol = mongoose.connection.db.collection('rechargetransactions');

    for (const [userId, w] of walletSnapshots.entries()) {
      await walletsCol.updateOne(
        { userId: new mongoose.Types.ObjectId(userId) },
        {
          $set: {
            balancePaise: Math.round(w.balancePaise || 0),
            onHoldPaise: Math.round(w.onHoldPaise || 0),
            updatedAt: new Date(),
          }
        },
        { upsert: true }
      );
    }

    for (const [orderId, tx] of rechargeTxSnapshots.entries()) {
      const doc = { ...tx };
      if (doc._id) doc._id = new mongoose.Types.ObjectId(doc._id);
      if (doc.userId) doc.userId = new mongoose.Types.ObjectId(doc.userId);
      await rtxsCol.updateOne(
        { orderId },
        { $set: doc },
        { upsert: true }
      );
    }
    await mongoose.disconnect();
    console.log('Restoration from transcript logs complete.');
  }
}

scanLogs().catch(console.error);
