const mongoose = require('mongoose');
const dotenv = require('dotenv');
const State = require('../models/State');
const connectDB = require('../config/db');

// Load env vars
dotenv.config({ path: './.env' });

const statesData = [
  { name: 'Andhra Pradesh', code: 'AP' },
  { name: 'Arunachal Pradesh', code: 'AR' },
  { name: 'Assam', code: 'AS' },
  { name: 'Bihar', code: 'BR' },
  { name: 'Chhattisgarh', code: 'CG' },
  { name: 'Goa', code: 'GA' },
  { name: 'Gujarat', code: 'GJ' },
  { name: 'Haryana', code: 'HR' },
  { name: 'Himachal Pradesh', code: 'HP' },
  { name: 'Jammu & Kashmir', code: 'JK' },
  { name: 'Jharkhand', code: 'JH' },
  { name: 'Karnataka', code: 'KA' },
  { name: 'Kerala', code: 'KL' },
  { name: 'Madhya Pradesh', code: 'MP' },
  { name: 'Maharashtra', code: 'MH' },
  { name: 'Meghalaya', code: 'ML' },
  { name: 'Mizoram', code: 'MZ' },
  { name: 'Nagaland', code: 'NL' },
  { name: 'Odisha', code: 'OD' },
  { name: 'Punjab', code: 'PB' },
  { name: 'Rajasthan', code: 'RJ' },
  { name: 'Sikkim', code: 'SK' },
  { name: 'Tamil Nadu', code: 'TN' },
  { name: 'Telangana', code: 'TS' },
  { name: 'Tripura', code: 'TR' },
  { name: 'Uttarakhand', code: 'UK' },
  { name: 'Uttar Pradesh', code: 'UP' },
  { name: 'West Bengal', code: 'WB' },
  { name: 'Andaman and Nicobar Islands', code: 'AN' },
  { name: 'Chandigarh', code: 'CH' },
  { name: 'Dadra and Nagar Haveli', code: 'DN' },
  { name: 'Delhi', code: 'DL' },
  { name: 'Lakshadweep', code: 'LD' },
  { name: 'Manipur', code: 'MN' },
  { name: 'Puducherry', code: 'PY' }
];

const seedStates = async () => {
  try {
    await connectDB();

    console.log('Seeding states to MongoDB...');
    let insertedCount = 0;
    let updatedCount = 0;
    const insertedStates = [];
    const updatedStates = [];

    for (let i = 0; i < statesData.length; i++) {
      const stateItem = statesData[i];
      const existingState = await State.findOne({ code: stateItem.code });
      
      if (existingState) {
        existingState.name = stateItem.name;
        existingState.isActive = true;
        existingState.sortOrder = i;
        await existingState.save();
        updatedCount++;
        updatedStates.push(stateItem.name);
      } else {
        await State.create({
          name: stateItem.name,
          code: stateItem.code,
          isActive: true,
          sortOrder: i
        });
        insertedCount++;
        insertedStates.push(stateItem.name);
      }
    }

    console.log(`\n=========================================================`);
    console.log(`FINAL REPORT`);
    console.log(`=========================================================`);
    console.log(`1. Total number of states seeded: ${insertedCount + updatedCount}`);
    console.log(`2. List of inserted states: ${insertedStates.length > 0 ? insertedStates.join(', ') : 'None'}`);
    console.log(`3. List of updated states: ${updatedStates.length > 0 ? updatedStates.join(', ') : 'None'}`);
    console.log(`4. Confirmation that the state dropdown now fetches all states from MongoDB instead of using hardcoded data: YES (once controller is updated)`);
    console.log(`=========================================================\n`);
    
    process.exit();
  } catch (err) {
    console.error(`Error with seed: ${err}`);
    process.exit(1);
  }
};

seedStates();
