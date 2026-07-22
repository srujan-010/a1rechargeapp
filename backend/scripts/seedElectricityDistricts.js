const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const ElectricityDistrict = require('../models/ElectricityDistrict');

// Load environment variables from backend/.env
dotenv.config({ path: path.join(__dirname, '../.env') });

const districtData = [
  // DVVNL (443)
  { operatorCode: 443, state: 'Uttar Pradesh', districtName: 'Agra', districtCode: 'AGRA' },
  { operatorCode: 443, state: 'Uttar Pradesh', districtName: 'Aligarh', districtCode: 'ALIGARH' },
  { operatorCode: 443, state: 'Uttar Pradesh', districtName: 'Mathura', districtCode: 'MATHURA' },
  
  // MVVNL (442)
  { operatorCode: 442, state: 'Uttar Pradesh', districtName: 'Lucknow', districtCode: 'LUCKNOW' },
  { operatorCode: 442, state: 'Uttar Pradesh', districtName: 'Ayodhya', districtCode: 'AYODHYA' },
  { operatorCode: 442, state: 'Uttar Pradesh', districtName: 'Bareilly', districtCode: 'BAREILLY' },

  // KESCO (52)
  { operatorCode: 52, state: 'Uttar Pradesh', districtName: 'Kanpur Nagar', districtCode: 'KANPUR_NAGAR' },
];

const seedDistricts = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    // Clear existing
    await ElectricityDistrict.deleteMany({});
    console.log('Cleared existing districts');

    await ElectricityDistrict.insertMany(districtData);
    console.log(`Successfully seeded ${districtData.length} districts`);
    
    process.exit(0);
  } catch (error) {
    console.error('Error seeding districts:', error);
    process.exit(1);
  }
};

seedDistricts();
