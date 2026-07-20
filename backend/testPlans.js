const mongoose = require('mongoose');
const dotenv = require('dotenv');
const connectDB = require('./config/db');
const plansService = require('./services/plans.service');
const ProviderOperator = require('./models/ProviderOperator');
const ProviderCircle = require('./models/ProviderCircle');
const RechargePlan = require('./models/RechargePlan');

dotenv.config();

const testPlans = async () => {
  try {
    await connectDB();
    
    // 1. Get Airtel operator and Punjab circle
    const operator = await ProviderOperator.findOne({ code: 'A' }); // Airtel
    const circle = await ProviderCircle.findOne({ code: '1' }); // Punjab

    if (!operator || !circle) {
      console.error('Operator or Circle not found in DB. Make sure they are seeded.');
      process.exit(1);
    }

    console.log(`Testing with Operator: ${operator.name} (${operator._id}), Circle: ${circle.state} (${circle._id})`);

    // 2. Clear cache to force a fetch
    await RechargePlan.deleteMany({ operatorId: operator._id, circleId: circle._id });
    console.log('Cleared existing cache for this combination.');

    // 3. Fetch Plans
    console.log('--- FETCHING FROM API ---');
    const plans1 = await plansService.getMobilePlans(operator._id, circle._id, '');
    console.log(`Fetched ${plans1.length} plans.`);
    if (plans1.length > 0) {
      console.log('Sample Plan 1:', plans1[0]);
    }

    // 4. Fetch Again (Should hit Cache)
    console.log('--- FETCHING FROM CACHE ---');
    const plans2 = await plansService.getMobilePlans(operator._id, circle._id, '');
    console.log(`Fetched ${plans2.length} plans from cache.`);

    // 5. Test Search
    console.log('--- FETCHING WITH SEARCH (299) ---');
    const searchedPlans = await plansService.getMobilePlans(operator._id, circle._id, '299');
    console.log(`Found ${searchedPlans.length} plans matching '299'.`);
    if (searchedPlans.length > 0) {
      console.log('Sample Match:', searchedPlans[0]);
    }

    process.exit(0);
  } catch (error) {
    console.error('Test Failed:', error.message);
    process.exit(1);
  }
};

testPlans();
