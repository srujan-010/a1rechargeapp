const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const User = require('../models/User');

async function listUsers() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('\n====================================================');
  console.log('[ALL USERS IN DATABASE]');

  const users = await User.find({}).sort({ createdAt: -1 }).lean();
  console.log(`Total users in database: ${users.length}`);
  users.forEach((u, i) => {
    console.log(`${i + 1}. _id: ${u._id}, name: "${u.name}", phone: "${u.phone}", email: "${u.email}", customId: "${u.customId}", retailerId: "${u.retailerId}", role: "${u.role}", accountType: "${u.accountType}"`);
  });

  console.log('====================================================\n');
  await mongoose.disconnect();
}

listUsers().catch(console.error);
