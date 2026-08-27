const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const ProviderCircle = require('../models/ProviderCircle');

async function inspectCircles() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('\n====================================================');
  console.log('[INSPECT ALL CIRCLES IN MONGODB]');
  
  const circles = await ProviderCircle.find({}).lean();
  console.log(`Total circles in DB: ${circles.length}`);
  circles.forEach(c => {
    console.log(`- _id: ${c._id}, name: "${c.name}", state: "${c.state}", code: "${c.code}", status: ${c.status}`);
  });
  console.log('====================================================\n');

  await mongoose.disconnect();
}

inspectCircles().catch(console.error);
