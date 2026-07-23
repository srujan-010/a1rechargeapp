require('dotenv').config({ path: __dirname + '/../.env' });
const mongoose = require('mongoose');
const GasOperator = require('../models/GasOperator');

const MONGO_URI = process.env.MONGODB_URI || process.env.MONGO_URI || 'mongodb://localhost:27017/a1recharge';

const gasOperators = [
  {
    "name":"Mahanagar Gas",
    "shortName":"MG",
    "planApi":{
        "operatorCode":62
    },
    "a1Topup":{
        "operatorCode":"MG"
    },
    "service":"Gas",
    "isActive":true
  },
  {
    "name":"Adani Gas",
    "shortName":"AG",
    "planApi":{
        "operatorCode":154
    },
    "a1Topup":{
        "operatorCode":"AG"
    },
    "service":"Gas",
    "isActive":true
  },
  {
    "name":"Gujarat Gas",
    "shortName":"GG",
    "planApi":{
        "operatorCode":64
    },
    "a1Topup":{
        "operatorCode":"GG"
    },
    "service":"Gas",
    "isActive":true
  },
  {
    "name":"Indraprastha Gas",
    "shortName":"IG",
    "planApi":{
        "operatorCode":63
    },
    "a1Topup":{
        "operatorCode":"IG"
    },
    "service":"Gas",
    "isActive":true
  },
  {
    "name":"HP Gas (HPCL)",
    "shortName":"HPCLGC",
    "planApi":{
        "operatorCode":161
    },
    "a1Topup":{
        "operatorCode":"HPCLGC"
    },
    "service":"Gas",
    "isActive":true
  }
];

async function seed() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('MongoDB connected.');

    // Clear existing
    await GasOperator.deleteMany({});
    console.log('Cleared existing gas operators.');

    // Insert new
    await GasOperator.insertMany(gasOperators);
    console.log(`Seeded ${gasOperators.length} gas operators successfully.`);

    process.exit(0);
  } catch (error) {
    console.error('Seeding error:', error);
    process.exit(1);
  }
}

seed();
