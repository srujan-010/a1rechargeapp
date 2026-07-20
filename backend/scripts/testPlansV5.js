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
    const opAirtel = await ProviderOperator.findOne({ code: 'A' }); // Prepaid Airtel
    const opAirtelPost = await ProviderOperator.findOne({ code: 'PAT' }); // Postpaid Airtel
    const opTataPlay = await ProviderOperator.findOne({ code: 'TTV' }); // DTH Tata Play
    const circlePB = await ProviderCircle.findOne({ code: '1' }); // Punjab

    if (!opAirtel || !opAirtelPost || !opTataPlay || !circlePB) {
      console.error('Missing seed data. Please run seedOperators.js first.');
      process.exit(1);
    }

    // Clear Cache
    await PlanCache.deleteMany({});
    console.log('Cleared all plan caches.');

    // --- TEST 1: Mobile Prepaid ---
    console.log('\n[TEST 1] Mobile Prepaid (Airtel - Punjab)');
    const prepaidPlans = await plansService.getMobilePrepaid(opAirtel._id, circlePB._id, '');
    console.log(`Prepaid Plans count: ${prepaidPlans.length}`);
    if (prepaidPlans.length > 0) {
      console.log('Sample:', prepaidPlans[0]);
    }

    // --- TEST 2: Mobile Postpaid ---
    console.log('\n[TEST 2] Mobile Postpaid (Airtel Postpaid - Punjab)');
    const postpaidPlans = await plansService.getMobilePostpaid(opAirtelPost._id, circlePB._id, '');
    console.log(`Postpaid Plans count: ${postpaidPlans.length}`);
    if (postpaidPlans.length > 0) {
      console.log('Sample:', postpaidPlans[0]);
    }

    // --- TEST 3: DTH Packs ---
    console.log('\n[TEST 3] DTH Packs (Tata Play)');
    const dthPacks = await plansService.getDthPacks(opTataPlay._id, '');
    console.log(`DTH Packs count: ${dthPacks.length}`);
    if (dthPacks.length > 0) {
      console.log('Sample:', dthPacks[0]);
    }

    // --- TEST 4: DTH Pack Details ---
    console.log('\n[TEST 4] DTH Pack Details (Tata Play - First Pack)');
    if (dthPacks.length > 0) {
        const packId = dthPacks[0].id || 'some_id'; 
        const dthPackDetails = await plansService.getDthPackDetails(opTataPlay._id, packId);
        console.log(`DTH Pack Details count (Channels/Categories): ${dthPackDetails.length}`);
        if (dthPackDetails.length > 0) {
            console.log('Sample:', dthPackDetails[0]);
        }
    } else {
        console.log('Skipping TEST 4, no DTH packs returned.');
    }

    // --- TEST 5: DTH Ala Carte ---
    console.log('\n[TEST 5] DTH Ala Carte (Tata Play)');
    const dthAlacarte = await plansService.getDthAlacarte(opTataPlay._id, '');
    console.log(`DTH Ala Carte count: ${dthAlacarte.length}`);
    if (dthAlacarte.length > 0) {
      console.log('Sample:', dthAlacarte[0]);
    }

    // --- TEST 6: Cache Hit ---
    console.log('\n[TEST 6] Cache Hit Test (Mobile Prepaid Airtel - Punjab)');
    const cachePrepaid = await plansService.getMobilePrepaid(opAirtel._id, circlePB._id, '');
    console.log(`Cache Prepaid count: ${cachePrepaid.length}`);

    console.log('\n--- ALL TESTS COMPLETE ---');
    process.exit(0);
  } catch (error) {
    console.error('Test Failed:', error.message);
    process.exit(1);
  }
};

runTests();
