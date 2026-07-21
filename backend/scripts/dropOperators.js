const mongoose = require('mongoose');
const dotenv = require('dotenv');
dotenv.config();

mongoose.connect(process.env.MONGODB_URI).then(async () => {
  console.log('Connected, dropping ProviderOperator...');
  await mongoose.connection.collection('provideroperators').drop().catch(e=>console.log('Drop failed/not exist'));
  console.log('Dropped.');
  process.exit(0);
});
