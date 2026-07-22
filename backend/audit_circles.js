const mongoose = require('mongoose');
const ProviderCircle = require('./models/ProviderCircle');
require('dotenv').config();
const connectDB = require('./config/db');

async function run() {
  await connectDB();

  const allCircles = await ProviderCircle.find({});
  console.log('Total circles in DB:', allCircles.length);
  process.exit(0);
}

run();
