const dotenv = require('dotenv');
dotenv.config({ path: '.env' });
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const plansService = require('../services/plans.service');
const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
const PlanCache = require('../models/PlanCache');

dotenv.config();

const runTests = async () => {
  try {
    await connectDB();
    
    console.log('--- PlansInfo V5 Architecture Test ---');

    // 1. Setup Data
    const opBSNL = await ProviderOperator.findOne({ name: 'BSNL', code: 'BT' }); // BSNL
    const circleMH = await ProviderCircle.findOne({ code: '4' }); // Maharashtra

    if (!opBSNL || !circleMH) {
      console.error('Missing seed data. Please run seedOperators.js first.');
      process.exit(1);
    }

    // Clear Cache
    await PlanCache.deleteMany({});
    console.log('Cleared all plan caches.');

    // --- TEST 1: Mobile Prepaid ---
    console.log('\n[TEST 1] Mobile Prepaid (BSNL - Maharashtra)');
    const prepaidPlans = await plansService.getMobilePrepaid(opBSNL._id, circleMH._id, '');
    console.log(`Prepaid Plans count: ${prepaidPlans.length}`);
    if (prepaidPlans.length > 0) {
      console.log('Sample:', prepaidPlans[0]);
    }

    console.log('\n--- TEST COMPLETE ---');
    process.exit(0);
  } catch (error) {
    console.error('Test Failed:', error.message);
    process.exit(1);
  }
};

runTests();
