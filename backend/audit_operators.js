const mongoose = require('mongoose');
const ProviderOperator = require('./models/ProviderOperator');
require('dotenv').config();
const connectDB = require('./config/db');

async function run() {
  await connectDB();

  const allOperators = await ProviderOperator.find({});
  console.log('Total operators in DB:', allOperators.length);
  
  if (allOperators.length > 0) {
    const services = [...new Set(allOperators.map(o => o.serviceType))];
    console.log('Available service types in DB:', services);
    
    console.log('Sample operator:');
    console.log(allOperators[0].name, allOperators[0].serviceType, allOperators[0].status);
  } else {
    console.log('ProviderOperator collection is completely empty!');
  }
  
  const prepaidCount = await ProviderOperator.countDocuments({ serviceType: new RegExp('^prepaid$', 'i') });
  console.log('Operators matching serviceType=prepaid:', prepaidCount);

  process.exit(0);
}

run();
