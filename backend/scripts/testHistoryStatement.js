require('dotenv').config({ path: './backend/.env' });
const mongoose = require('mongoose');

async function testHistoryStatement() {
  await mongoose.connect(process.env.MONGODB_URI);
  const RechargeTransaction = mongoose.model('RechargeTransaction', new mongoose.Schema({}, { strict: false }));
  const Transaction = mongoose.model('Transaction', new mongoose.Schema({}, { strict: false }));

  const userId = new mongoose.Types.ObjectId('6a8c238da11c66be44e44ee2');
  const userIds = [userId, userId.toString()];

  const baseQuery = { userId: { $in: userIds } };

  console.log('[HISTORY TEST] Running getStatement query for user 6a8c238da11c66be44e44ee2...');
  
  const globalTransactions = await Transaction.find(baseQuery)
    .sort({ createdAt: -1 })
    .lean();

  console.log('Global Transaction count:', globalTransactions.length);

  const formattedGlobal = globalTransactions.map(t => {
    return {
      id: String(t._id),
      type: t.type || 'debit',
      serviceType: t.serviceType || t.service || 'other',
      operatorName: t.operatorName || (t.metadata && t.metadata.operator) || 'Operator',
      customerIdentifier: t.customerIdentifier || (t.metadata && t.metadata.customerNumber) || '',
      amount: t.amountPaise || Math.round((t.amount || 0) * 100),
      status: String(t.status || 'pending').toLowerCase(),
      createdAt: t.createdAt,
      referenceNumber: t.referenceNumber || t.orderId || (t.metadata && t.metadata.orderId),
    };
  });

  const rechargeTxns = await RechargeTransaction.find(baseQuery)
    .sort({ createdAt: -1 })
    .lean();

  console.log('RechargeTransaction count:', rechargeTxns.length);

  const existingRefIds = new Set(formattedGlobal.map(t => t.referenceNumber).filter(Boolean));

  const formattedRecharges = rechargeTxns
    .filter(r => !existingRefIds.has(r.orderId) && !existingRefIds.has(String(r._id)))
    .map(r => {
      const serviceType = r.serviceType === 'dth' ? 'dth' : 'mobile_recharge';
      return {
        id: String(r._id),
        type: 'debit',
        serviceType,
        operatorName: r.internalOperatorName || r.operatorCode || 'Operator',
        customerIdentifier: r.mobileNumber || '',
        amount: Math.round((r.amount || 0) * 100),
        status: String(r.status || 'pending').toLowerCase(),
        createdAt: r.createdAt,
        referenceNumber: r.orderId,
      };
    });

  const allTransactions = [...formattedGlobal, ...formattedRecharges];
  console.log('Total merged transactions:', allTransactions.length);
  console.log('Transactions list:');
  for (const t of allTransactions) {
    console.log(`  - [${t.status}] ID: ${t.id}, Ref: ${t.referenceNumber}, Amount: ₹${t.amount/100}, Service: ${t.serviceType}`);
  }

  await mongoose.disconnect();
}

testHistoryStatement().catch(console.error);
