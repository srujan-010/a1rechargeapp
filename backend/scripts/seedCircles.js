const mongoose = require('mongoose');
const dotenv = require('dotenv');
const ProviderCircle = require('../models/ProviderCircle');
const connectDB = require('../config/db');

dotenv.config();

const circles = [
  { state: 'Andhra Pradesh', code: '13' },
  { state: 'Assam', code: '24' },
  { state: 'Bihar', code: '17' },
  { state: 'Chhattisgarh', code: '27' },
  { state: 'Gujarat', code: '12' },
  { state: 'Haryana', code: '20' },
  { state: 'Himachal Pradesh', code: '21' },
  { state: 'Jammu And Kashmir', code: '25' },
  { state: 'Jharkhand', code: '22' },
  { state: 'Karnataka', code: '9' },
  { state: 'Kerala', code: '14' },
  { state: 'Madhya Pradesh', code: '16' },
  { state: 'Maharashtra', code: '4' },
  { state: 'Orissa', code: '23' },
  { state: 'Punjab', code: '1' },
  { state: 'Rajasthan', code: '18' },
  { state: 'Tamil Nadu', code: '8' },
  { state: 'Uttar Pradesh East', code: '10' },
  { state: 'West Bengal', code: '2' },
  { state: 'Uttar Pradesh West', code: '11' },
  { state: 'Mumbai', code: '3' },
  { state: 'Delhi', code: '5' },
  { state: 'CHENNAI', code: '7' },
  { state: 'NORTH EAST', code: '26' },
  { state: 'Kolkata', code: '6' }
];

const seedCircles = async () => {
  try {
    await connectDB();
    console.log('Seeding Circles...');

    for (const circle of circles) {
      await ProviderCircle.findOneAndUpdate(
        { provider: 'A1Topup', code: circle.code },
        { 
          provider: 'A1Topup',
          state: circle.state,
          code: circle.code
        },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
    }
    
    console.log(`Successfully seeded ${circles.length} circles.`);
    process.exit(0);
  } catch (error) {
    console.error('Error seeding circles:', error);
    process.exit(1);
  }
};

seedCircles();
