const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const ElectricityOperator = require('../models/ElectricityOperator');

// Load environment variables from backend/.env
dotenv.config({ path: path.join(__dirname, '../.env') });

const defaultRequiredFields = [
  {
    key: "bill_number",
    label: "Consumer Number",
    placeholder: "Enter Consumer Number",
    required: true,
    type: "text"
  },
  {
    key: "optional1",
    label: "Billing Unit",
    placeholder: "Enter Billing Unit",
    required: false,
    type: "text"
  },
  {
    key: "optional2",
    label: "",
    placeholder: "",
    required: false,
    type: "text"
  },
  {
    key: "optional3",
    label: "",
    placeholder: "",
    required: false,
    type: "text"
  }
];

const operatorsData = [
  {
    "name": "OD NESCO",
    "operatorCode": 499,
    "state": "Odisha",
    "stateCode": "OD"
  },
  {
    "name": "Eastern Power Distribution Company of Andhra Pradesh Limited (APEPDCL)",
    "operatorCode": 498,
    "state": "Andhra Pradesh",
    "stateCode": "AP"
  },
  {
    "name": "Ladakh Power Distribution (LPDD)",
    "operatorCode": 497,
    "state": "Jammu & Kashmir",
    "stateCode": "JK"
  },
  {
    "name": "Kashmir Power Distribution (KPDCL)",
    "operatorCode": 496,
    "state": "Jammu & Kashmir",
    "stateCode": "JK"
  },
  {
    "name": "B.E.S.T Mumbai",
    "operatorCode": 495,
    "state": "Maharashtra",
    "stateCode": "MH"
  },
  {
    "name": "Co-Operative Electric Supply Society LTD",
    "operatorCode": 494,
    "state": "Telangana",
    "stateCode": "TS"
  },
  {
    "name": "Torrent Power - Ahmedabad",
    "operatorCode": 493,
    "state": "Gujarat",
    "stateCode": "GJ"
  },
  {
    "name": "MN Manipur State Power Distribution Company Ltd",
    "operatorCode": 492,
    "state": "Manipur",
    "stateCode": "MN"
  },
  {
    "name": "Northern Power Distribution Company of Telangana Ltd",
    "operatorCode": 475,
    "state": "Telangana",
    "stateCode": "TS"
  },
  {
    "name": "Southern Power Distribution Company of Telangana Ltd",
    "operatorCode": 474,
    "state": "Telangana",
    "stateCode": "TS"
  },
  {
    "name": "Jammu Power Distribution (JPDCL)",
    "operatorCode": 456,
    "state": "Jammu & Kashmir",
    "stateCode": "JK"
  },
  {
    "name": "Chandigarh Electricity Department",
    "operatorCode": 455,
    "state": "Chandigarh",
    "stateCode": "CH"
  },
  {
    "name": "TP Southern Odisha Distribution Ltd - Smart Prepaid Meter Recharge",
    "operatorCode": 454,
    "state": "Odisha",
    "stateCode": "OD"
  },
  {
    "name": "BSES Rajdhani Prepaid Meter Recharge",
    "operatorCode": 449,
    "state": "Delhi",
    "stateCode": "DL"
  },
  {
    "name": "Assam Power Distribution Company Ltd - Smart Prepaid Recharge",
    "operatorCode": 448,
    "state": "Assam",
    "stateCode": "AS"
  },
  {
    "name": "Department of Power, Government of Arunachal Pradesh",
    "operatorCode": 447,
    "state": "Arunachal Pradesh",
    "stateCode": "AR"
  },
  {
    "name": "India Power Corporation Limited (IPCL)",
    "operatorCode": 446,
    "state": "West Bengal",
    "stateCode": "WB"
  },
  {
    "name": "South Bihar Power Distribution Company Ltd",
    "operatorCode": 445,
    "state": "Bihar",
    "stateCode": "BR"
  },
  {
    "name": "Tata Power - Delhi",
    "operatorCode": 444,
    "state": "Delhi",
    "stateCode": "DL"
  },
  {
    "name": "Dakshinanchal Vidyut Vitran Nigam Limited (DVVNL)",
    "operatorCode": 443,
    "state": "Uttar Pradesh",
    "stateCode": "UP"
  },
  {
    "name": "Madhyanchal Vidyut Vitran Nigam Limited (MVVNL)",
    "operatorCode": 442,
    "state": "Uttar Pradesh",
    "stateCode": "UP"
  },
  {
    "name": "Paschimanchal Vidyut Vitran Nigam Limited (PVVVNL)",
    "operatorCode": 438,
    "state": "Uttar Pradesh",
    "stateCode": "UP"
  },
  {
    "name": "Purvanchal Vidyut Vitran Nigam Limited (PUVVNL)",
    "operatorCode": 436,
    "state": "Uttar Pradesh",
    "stateCode": "UP"
  },
  {
    "name": "WBSEDCL - West Bengal",
    "operatorCode": 155,
    "state": "West Bengal",
    "stateCode": "WB"
  },
  {
    "name": "Ajmer Vidyut Vitran Nigam",
    "operatorCode": 153,
    "state": "Rajasthan",
    "stateCode": "RJ"
  },
  {
    "name": "Central Power Distribution Corporation Ltd (APCPDCL)",
    "operatorCode": 152,
    "state": "Andhra Pradesh",
    "stateCode": "AP"
  },
  {
    "name": "APEPDCL - Andhra Pradesh",
    "operatorCode": 151,
    "state": "Andhra Pradesh",
    "stateCode": "AP"
  },
  {
    "name": "APSPDCL - Andhra Pradesh",
    "operatorCode": 150,
    "state": "Andhra Pradesh",
    "stateCode": "AP"
  },
  {
    "name": "BESCOM - Bengaluru",
    "operatorCode": 149,
    "state": "Karnataka",
    "stateCode": "KA"
  },
  {
    "name": "BESL - Bharatpur",
    "operatorCode": 148,
    "state": "Rajasthan",
    "stateCode": "RJ"
  },
  {
    "name": "BkESL - Bikaner",
    "operatorCode": 146,
    "state": "Rajasthan",
    "stateCode": "RJ"
  },
  {
    "name": "BSES Yamuna - Delhi",
    "operatorCode": 144,
    "state": "Delhi",
    "stateCode": "DL"
  },
  {
    "name": "Lakshadweep Electricity Department",
    "operatorCode": 143,
    "state": "Lakshadweep",
    "stateCode": "LD"
  },
  {
    "name": "DHBVN - Haryana",
    "operatorCode": 142,
    "state": "Haryana",
    "stateCode": "HR"
  },
  {
    "name": "DNHPDCL - Dadra & Nagar Haveli",
    "operatorCode": 141,
    "state": "Dadra and Nagar Haveli",
    "stateCode": "DN"
  },
  {
    "name": "GESCOM - Karnataka",
    "operatorCode": 140,
    "state": "Karnataka",
    "stateCode": "KA"
  },
  {
    "name": "Sikkim Power (Urban)",
    "operatorCode": 138,
    "state": "Sikkim",
    "stateCode": "SK"
  },
  {
    "name": "Torrent Power - Bhiwandi",
    "operatorCode": 137,
    "state": "Maharashtra",
    "stateCode": "MH"
  },
  {
    "name": "JUSCO - Jamshedpur",
    "operatorCode": 136,
    "state": "Jharkhand",
    "stateCode": "JH"
  },
  {
    "name": "Kota Electricity Distribution",
    "operatorCode": 135,
    "state": "Rajasthan",
    "stateCode": "RJ"
  },
  {
    "name": "Madhya Kshetra Vitaran",
    "operatorCode": 134,
    "state": "Madhya Pradesh",
    "stateCode": "MP"
  },
  {
    "name": "MEPDCL - Meghalaya",
    "operatorCode": 132,
    "state": "Meghalaya",
    "stateCode": "ML"
  },
  {
    "name": "MSEDC - Maharashtra",
    "operatorCode": 131,
    "state": "Maharashtra",
    "stateCode": "MH"
  },
  {
    "name": "Muzaffarpur Vidyut Vitran",
    "operatorCode": 127,
    "state": "Bihar",
    "stateCode": "BR"
  },
  {
    "name": "NBPDCL - Bihar",
    "operatorCode": 126,
    "state": "Bihar",
    "stateCode": "BR"
  },
  {
    "name": "Noida Power",
    "operatorCode": 125,
    "state": "Uttar Pradesh",
    "stateCode": "UP"
  },
  {
    "name": "Paschim Kshetra Vitaran",
    "operatorCode": 124,
    "state": "Madhya Pradesh",
    "stateCode": "MP"
  },
  {
    "name": "PSPCL - Punjab",
    "operatorCode": 123,
    "state": "Punjab",
    "stateCode": "PB"
  },
  {
    "name": "Goa Electricity Department",
    "operatorCode": 121,
    "state": "Goa",
    "stateCode": "GA"
  },
  {
    "name": "UPCL - Uttarakhand",
    "operatorCode": 119,
    "state": "Uttarakhand",
    "stateCode": "UK"
  },
  {
    "name": "SOUTHCO - Odisha",
    "operatorCode": 118,
    "state": "Odisha",
    "stateCode": "OD"
  },
  {
    "name": "Tata Power - Mumbai",
    "operatorCode": 116,
    "state": "Maharashtra",
    "stateCode": "MH"
  },
  {
    "name": "TNEB - Tamil Nadu",
    "operatorCode": 115,
    "state": "Tamil Nadu",
    "stateCode": "TN"
  },
  {
    "name": "TPADL - Ajmer",
    "operatorCode": 114,
    "state": "Rajasthan",
    "stateCode": "RJ"
  },
  {
    "name": "TSECL - Tripura",
    "operatorCode": 112,
    "state": "Tripura",
    "stateCode": "TR"
  },
  {
    "name": "UGVCL - Gujarat",
    "operatorCode": 111,
    "state": "Gujarat",
    "stateCode": "GJ"
  },
  {
    "name": "UPPCL - Postpaid & Smart Meter",
    "operatorCode": 110,
    "state": "Uttar Pradesh",
    "stateCode": "UP"
  },
  {
    "name": "Ajmer Vidyut",
    "operatorCode": 95,
    "state": "Rajasthan",
    "stateCode": "RJ"
  },
  {
    "name": "Odisha DISCOM",
    "operatorCode": 92,
    "state": "Odisha",
    "stateCode": "OD"
  },
  {
    "name": "MESCOM - Mangalore",
    "operatorCode": 91,
    "state": "Karnataka",
    "stateCode": "KA"
  },
  {
    "name": "Daman & Diu Electricity",
    "operatorCode": 90,
    "state": "Dadra and Nagar Haveli",
    "stateCode": "DN"
  },
  {
    "name": "JBVNL - Jharkhand",
    "operatorCode": 89,
    "state": "Jharkhand",
    "stateCode": "JH"
  },
  {
    "name": "CESU - Odisha",
    "operatorCode": 88,
    "state": "Odisha",
    "stateCode": "OD"
  },
  {
    "name": "NDMC - Delhi",
    "operatorCode": 87,
    "state": "Delhi",
    "stateCode": "DL"
  },
  {
    "name": "UHBVN - Haryana",
    "operatorCode": 86,
    "state": "Haryana",
    "stateCode": "HR"
  },
  {
    "name": "Torrent Power - Agra",
    "operatorCode": 85,
    "state": "Uttar Pradesh",
    "stateCode": "UP"
  },
  {
    "name": "APDCL (Non-RAPDR) - Assam",
    "operatorCode": 84,
    "state": "Assam",
    "stateCode": "AS"
  },
  {
    "name": "Jodhpur Vidyut Vitran Nigam Ltd",
    "operatorCode": 79,
    "state": "Rajasthan",
    "stateCode": "RJ"
  },
  {
    "name": "Jaipur Vidyut Vitran Nigam Ltd",
    "operatorCode": 78,
    "state": "Rajasthan",
    "stateCode": "RJ"
  },
  {
    "name": "Poorv Kshetra Vitaran (Rural)",
    "operatorCode": 76,
    "state": "Madhya Pradesh",
    "stateCode": "MP"
  },
  {
    "name": "PGVCL - Gujarat",
    "operatorCode": 75,
    "state": "Gujarat",
    "stateCode": "GJ"
  },
  {
    "name": "DGVCL - Gujarat",
    "operatorCode": 74,
    "state": "Gujarat",
    "stateCode": "GJ"
  },
  {
    "name": "MGVCL - Gujarat",
    "operatorCode": 73,
    "state": "Gujarat",
    "stateCode": "GJ"
  },
  {
    "name": "KSEBL - Kerala",
    "operatorCode": 69,
    "state": "Kerala",
    "stateCode": "KL"
  },
  {
    "name": "Himachal Pradesh State Electricity Board",
    "operatorCode": 61,
    "state": "Himachal Pradesh",
    "stateCode": "HP"
  },
  {
    "name": "HESCOM - Karnataka",
    "operatorCode": 60,
    "state": "Karnataka",
    "stateCode": "KA"
  },
  {
    "name": "Chhattisgarh State Electricity Board",
    "operatorCode": 59,
    "state": "Chhattisgarh",
    "stateCode": "CG"
  },
  {
    "name": "CESC - West Bengal",
    "operatorCode": 58,
    "state": "West Bengal",
    "stateCode": "WB"
  },
  {
    "name": "CESCOM - Karnataka",
    "operatorCode": 57,
    "state": "Karnataka",
    "stateCode": "KA"
  },
  {
    "name": "Torrent Power - Surat",
    "operatorCode": 56,
    "state": "Gujarat",
    "stateCode": "GJ"
  },
  {
    "name": "Madhya Kshetra Vitaran (Urban)",
    "operatorCode": 55,
    "state": "Madhya Pradesh",
    "stateCode": "MP"
  },
  {
    "name": "Poorv Kshetra Vitaran (Urban)",
    "operatorCode": 54,
    "state": "Madhya Pradesh",
    "stateCode": "MP"
  },
  {
    "name": "Torrent Power",
    "operatorCode": 53,
    "state": "Gujarat",
    "stateCode": "GJ"
  },
  {
    "name": "KESCO - Kanpur",
    "operatorCode": 52,
    "state": "Uttar Pradesh",
    "stateCode": "UP"
  },
  {
    "name": "Electricity Department - Puducherry",
    "operatorCode": 51,
    "state": "Puducherry",
    "stateCode": "PY"
  },
  {
    "name": "Adani Electricity - Mumbai",
    "operatorCode": 50,
    "state": "Maharashtra",
    "stateCode": "MH"
  },
  {
    "name": "Power & Electricity Department - Mizoram",
    "operatorCode": 49,
    "state": "Mizoram",
    "stateCode": "MZ"
  },
  {
    "name": "Sikkim Power (Rural)",
    "operatorCode": 48,
    "state": "Sikkim",
    "stateCode": "SK"
  },
  {
    "name": "UPPCL - Postpaid & Smart Meter Recharge",
    "operatorCode": 47,
    "state": "Uttar Pradesh",
    "stateCode": "UP"
  },
  {
    "name": "WESCO - Odisha",
    "operatorCode": 46,
    "state": "Odisha",
    "stateCode": "OD"
  },
  {
    "name": "Department of Power - Nagaland",
    "operatorCode": 45,
    "state": "Nagaland",
    "stateCode": "NL"
  }
];

const seedOperators = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    // Clear existing
    await ElectricityOperator.deleteMany({});
    console.log('Cleared existing operators');

    // Map to schema
    const formattedOperators = operatorsData.map((op, index) => {
      let state = op.state;
      let stateCode = op.stateCode;

      return {
        ...op,
        shortName: op.name.split(' ')[0],
        state: state,
        stateCode: stateCode,
        serviceType: 'electricity',
        category: 'Electricity',
        isPopular: index < 10, // Just an example, mark first 10 as popular
        isActive: true,
        sortOrder: index,
        requiresDistrictCode: [443, 442, 52].includes(op.operatorCode),
        requiresMobile: false,
        requiresDOB: false,
        searchKeywords: op.name.split(' ').map(w => w.toLowerCase()),
        requiredFields: defaultRequiredFields
      };
    });

    await ElectricityOperator.insertMany(formattedOperators);
    console.log(`Successfully seeded ${formattedOperators.length} operators`);
    
    process.exit(0);
  } catch (error) {
    console.error('Error seeding operators:', error);
    process.exit(1);
  }
};

seedOperators();
