const mongoose = require('mongoose');
require('dotenv').config({ path: __dirname + '/../.env' });
const connectDB = require('../config/db');
const ProviderOperator = require('../models/ProviderOperator');

async function fixOperatorPlanCodes() {
  try {
    await connectDB();
    console.log('Connected to MongoDB for fixing operator plan codes...');

    const updates = [
      // DTH Operators
      { filter: { serviceType: /^DTH$/i, code: 'ATV' }, update: { name: 'AIRTEL DTH', a1TopupCode: 'ATV', plansApiCode: '24', plansInfoCode: '24' } },
      { filter: { serviceType: /^DTH$/i, code: 'DTV' }, update: { name: 'DISH TV', a1TopupCode: 'DTV', plansApiCode: '25', plansInfoCode: '25' } },
      { filter: { serviceType: /^DTH$/i, code: 'RBTV' }, update: { name: 'RELIANCE BIGTV', a1TopupCode: 'RBTV', plansApiCode: '26', plansInfoCode: '26' } },
      { filter: { serviceType: /^DTH$/i, code: 'STV' }, update: { name: 'SUN DIRECT', a1TopupCode: 'STV', plansApiCode: '27', plansInfoCode: '27' } },
      { filter: { serviceType: /^DTH$/i, code: 'TTV' }, update: { name: 'TATA SKY', a1TopupCode: 'TTV', plansApiCode: '28', plansInfoCode: '28' } },
      { filter: { serviceType: /^DTH$/i, code: 'VTV' }, update: { name: 'VIDEOCON D2H', a1TopupCode: 'VTV', plansApiCode: '29', plansInfoCode: '29' } },

      // BSNL Operators
      { filter: { code: 'BT' }, update: { name: 'BSNL TOPUP', a1TopupCode: 'BT', plansApiCode: '4', plansInfoCode: '4' } },
      { filter: { code: 'BR' }, update: { name: 'BSNL SPECIAL', a1TopupCode: 'BR', plansApiCode: '5', plansInfoCode: '5' } },

      // Mobile Operators
      { filter: { code: 'A', serviceType: 'Mobile' }, update: { a1TopupCode: 'A', plansApiCode: '2', plansInfoCode: 'AT' } },
      { filter: { code: 'V', serviceType: 'Mobile' }, update: { a1TopupCode: 'V', plansApiCode: '23', plansInfoCode: 'ID' } },
      { filter: { code: 'RC', serviceType: 'Mobile' }, update: { a1TopupCode: 'RC', plansApiCode: '11', plansInfoCode: 'RJ' } },
      { filter: { code: 'I', serviceType: 'Mobile' }, update: { a1TopupCode: 'I', plansApiCode: '23', plansInfoCode: 'ID' } },
    ];

    for (const item of updates) {
      const res = await ProviderOperator.updateMany(item.filter, { $set: item.update });
      console.log(`Updated operator matching ${JSON.stringify(item.filter)}: modifiedCount=${res.modifiedCount}`);
    }

    console.log('Finished updating operator plan codes in DB.');
    process.exit(0);
  } catch (error) {
    console.error('Error fixing operator plan codes:', error);
    process.exit(1);
  }
}

fixOperatorPlanCodes();
