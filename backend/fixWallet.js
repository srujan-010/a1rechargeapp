const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
dotenv.config({ path: path.join(__dirname, '.env') });

mongoose.connect(process.env.MONGODB_URI).then(async () => {
  const User = require('./models/User');
  const Wallet = require('./models/Wallet');
  
  const users = await User.find({ $or: [{ uniqueId: 'RET000003' }, { retailerId: 'RET000003' }] });
  if (users.length === 0) {
    console.log('User not found');
    process.exit(0);
  }
  
  const user = users[0];
  console.log('Found user:', user.name);
  
  const wallet = await Wallet.findOne({ userId: user._id });
  console.log('Wallet BEFORE:', wallet);
  
  if (wallet) {
    wallet.balancePaise = 16000;
    await wallet.save();
    console.log('Wallet AFTER:', wallet);
  } else {
    console.log('No wallet found for user');
  }
  
  process.exit(0);
}).catch(console.error);
