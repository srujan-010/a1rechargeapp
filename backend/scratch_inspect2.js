const mongoose = require('mongoose');
require('dotenv').config();

const providerOperatorSchema = new mongoose.Schema({}, { strict: false, timestamps: true });
const ProviderOperator = mongoose.model('ProviderOperator', providerOperatorSchema, 'provideroperators');

const operatorCommissionSchema = new mongoose.Schema({}, { strict: false, timestamps: true });
const OperatorCommission = mongoose.model('OperatorCommission', operatorCommissionSchema, 'operatorcommissions');

async function inspect() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/a1recharge';
  console.log('Connecting to MongoDB:', mongoUri);
  await mongoose.connect(mongoUri);

  console.log('\n--- ALL PROVIDER OPERATORS (from Admin) ---');
  const poDocs = await ProviderOperator.find({}).lean();
  console.log(`Total ProviderOperator docs: ${poDocs.length}`);
  for (const doc of poDocs) {
    console.log(`ID: ${doc._id} | provider: ${doc.provider} | name: ${doc.name} | code: ${doc.code} | serviceType: ${doc.serviceType} | plansInfoCode: ${doc.plansInfoCode} | status: ${doc.status}`);
  }

  console.log('\n--- ALL OPERATOR COMMISSIONS ---');
  const opDocs = await OperatorCommission.find({}).lean();
  console.log(`Total OperatorCommission docs: ${opDocs.length}`);
  for (const doc of opDocs) {
    console.log(`ID: ${doc._id} | accountType: ${doc.accountType} | serviceType: ${doc.serviceType} | code: ${doc.operatorCode} | name: ${doc.operatorName} | personalComm: ${doc.personalCommission} | retailerComm: ${doc.retailerCommission} | providerComm: ${doc.providerCommission} | status: ${doc.status}`);
  }

  await mongoose.disconnect();
  console.log('\nDone inspection.');
}

inspect().catch(err => {
  console.error('Inspect error:', err);
  process.exit(1);
});
