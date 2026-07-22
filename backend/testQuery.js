const mongoose = require('mongoose');
const dotenv = require('dotenv');
dotenv.config();
const connectDB = require('./config/db');

connectDB().then(async () => {
  console.log('Connected to MongoDB');
  const ProviderOperator = require('./models/ProviderOperator');
  
  const all = await ProviderOperator.countDocuments({});
  const mobile = await ProviderOperator.countDocuments({serviceType:'Mobile'});
  const serviceMobile = await ProviderOperator.countDocuments({service:'mobile'});
  const typeMobile = await ProviderOperator.countDocuments({type:'Mobile'});
  const allDocs = await ProviderOperator.find({name: 'Airtel'}).limit(1);
  
  console.log('Counts:');
  console.log('db.operators.find({}):', all);
  console.log('db.operators.find({serviceType:"Mobile"}):', mobile);
  console.log('db.operators.find({service:"mobile"}):', serviceMobile);
  console.log('db.operators.find({type:"Mobile"}):', typeMobile);
  
  console.log('Sample Airtel Document:');
  console.log(JSON.stringify(allDocs[0], null, 2));
  
  process.exit(0);
});
