const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
dotenv.config({ path: path.join(__dirname, '.env') });
const connectDB = require('./config/db');
connectDB().then(async () => {
  require('./models/ProviderOperator');
  const PlanCache = require('./models/PlanCache');
  
  const ProviderOperator = mongoose.model('ProviderOperator');
  const bsnlOps = await ProviderOperator.find({ name: /BSNL/i });
  const bsnlIds = bsnlOps.map(o => o._id);
  
  const bsnlCache = await PlanCache.findOne({ 
    service: 'mobile', 
    type: 'prepaid',
    operatorId: { $in: bsnlIds }
  });
  
  if (bsnlCache && bsnlCache.plans) {
    const plans = bsnlCache.plans;
    const cats = {};
    for (const p of plans) {
      if (!cats[p.category]) cats[p.category] = p;
    }
    console.log(JSON.stringify(cats, null, 2));
  } else {
    console.log('No cache found');
  }
  process.exit(0);
}).catch(console.error);
