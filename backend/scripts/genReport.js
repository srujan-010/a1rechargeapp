const mongoose = require('mongoose');
const dotenv = require('dotenv');
const ElectricityOperator = require('../models/ElectricityOperator');

const path = require('path');
dotenv.config({ path: path.join(__dirname, '../.env') });

async function run() {
  await mongoose.connect(process.env.MONGODB_URI);
  const operators = await ElectricityOperator.find({});
  console.log(`Total operators in MongoDB: ${operators.length}`);
  
  const grouped = {};
  let missing = [];

  for (let op of operators) {
    if (!op.stateCode || !op.state) {
      missing.push(op.name);
    }
    
    if (!grouped[op.stateCode]) {
      grouped[op.stateCode] = [];
    }
    grouped[op.stateCode].push(op.name);
  }

  console.log('Operators grouped by state:');
  for (let state in grouped) {
    console.log(`- ${state}: ${grouped[state].join(', ')}`);
  }

  console.log(`\nMissing state mappings: ${missing.length > 0 ? missing.join(', ') : 'None'}`);
  process.exit(0);
}

run();
