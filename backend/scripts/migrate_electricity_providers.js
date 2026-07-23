const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
dotenv.config({ path: path.join(__dirname, '../.env') });

const ElectricityOperator = require('../models/ElectricityOperator');

const a1TopupMappings = {
  "North Bihar Electricity": "NBE",
  "JBVNL - JHARKHAND": "JBVNL",
  "Assam Power Distribution Company Ltd (RAPDR)": "APDCLR",
  "Mangalore Electricity Supply Co. Ltd (MESCOM) - RAPDR": "MESCOMR",
  "APDCL (Non-RAPDR) - ASSAM": "APDCLN",
  "Mangalore Electricity Supply Co. Ltd (Non-RAPDR)": "MESCOMNR",
  "BSES Rajdhani Power Limited": "BSES",
  "BSES Yamuna Power Limited": "BSESY",
  "Tata Power Delhi Limited": "TPD",
  "Tata Power Mumbai": "TPDM",
  "Hubli Electricity Supply Company": "HESCOM",
  "South Bihar Electricity": "SBE",
  "BEST Mumbai": "BEST",
  "B.E.S.T Mumbai": "BEST",
  "Ajmer Vidyut Vitran Nigam": "AJV",
  "Bangalore Electricity Supply Company": "BESCOM",
  "CESC West Bengal": "CESC",
  "Jaipur Vidyut Vitran Nigam": "JVV",
  "Jodhpur Vidyut Vitran Nigam": "JDVV",
  "MP Madhya Kshetra Urban": "MKV",
  "MSEDC Maharashtra": "MSEDC",
  "Noida Power": "NP",
  "Paschim Kshetra Vitaran": "PKV",
  "Southern Power Andhra Pradesh": "SPA",
  "Southern Power Telangana": "SPT",
  "Torrent Power Agra": "TRP",
  "Central Power Distribution AP": "APCPDCL",
  "Department of Power Arunachal": "ARPDOP",
  "WESCO Odisha": "WESCO",
  "Paschim Gujarat Vij": "PGVCL",
  "Bharatpur Electricity": "BHES",
  "Muzaffarpur Vidyut Vitran": "MVV",
  "Madhya Gujarat Vij": "MGVCL",
  "MEPDCL": "MEPDCL",
  "KEDL Kota": "KEDL",
  "Dakshin Gujarat Vij": "DGVCL",
  "WBSEDCL": "WBSEDCL",
  "SNDL Power Nagpur": "SNDL",
  "Bikaner Electricity Supply": "BESL",
  "India Power West Bengal": "IPWB",
  "BrihanMumbai Electric Supply": "BMESTU",
  "APEPDCL": "APEPDCL",
  "TNEB": "TNEB",
  "UPPCL Urban": "UPPCLU",
  "UPPCL Rural": "UPPCLR",
  "Dakshin Haryana Bijli": "DHBVN",
  "TSNPDCL": "TSNPDCL",
  "DNH Power Distribution": "DDCL",
  "GESCOM": "GESCL",
  "India Power Corporation": "IPCL",
  "JUSCO": "JUSCL",
  "CSPDCL": "CSPDCL",
  "Goa Electricity": "GOAELC",
  "UGVCL": "UGVCL",
  "Torrent Power Surat": "TORRENTSUR",
  "Torrent Power Ahmedabad": "TORRENTAHM",
  "Gift Power": "GPCL",
  "HPSEBL": "HPSEBL",
  "Jammu & Kashmir PDD": "JKPDD",
  "CESCOM Mysore": "CESCOM",
  "North Delhi Power": "NDPL",
  "Municipal Corporation Gurugram": "MCG",
  "PSPCL": "PSPCL",
  "TSECL": "TSECL",
  "UHBVN": "UHBV",
  "UKPCL": "UKPCL",
  "KSEB": "KSEB",
  "Kannan Devan Hills Power": "KDHPCPL",
  "Lakshadweep Electricity Department": "LED",
  "MPPKVVCL Jabalpur": "MPPKVVCLPU",
  "MPPKVVCL Rural": "MPPKVVCLPU",
  "MPPKVVCL Madhya Rural": "MPPKVVCLMR",
  "MPPKVVCL Urban": "MPPKVVCL",
  "Reliance Energy": "RELIANCE",
  "Torrent Power Shil": "TORRENTSHI",
  "Torrent Power Bhiwandi": "TORRENTBHI",
  "Adani Electricity": "AEML",
  "MSPDCL Prepaid": "MSPDCLPR",
  "Power & Electricity Mizoram": "MPED",
  "Department of Power Nagaland": "NDOP",
  "NDMC": "NDMC",
  "NESCO Odisha": "NESCO",
  "SOUTHCO Odisha": "SOUTHCO",
  "TPCODL": "TPCODL",
  "Puducherry Electricity": "PGPED",
  "TP Ajmer Distribution": "TPADL",
  "Sikkim Power Rural": "SPR",
  "Sikkim Power Urban": "SPU",
  "KESCO": "KESCO",
  "Torrent Power Dahej": "TORRENTDAH",
  "Madhyanchal Vidyut Vitran Nigam": "MVVNL"
};

async function runMigration() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    const operators = await ElectricityOperator.find({});
    let updatedCount = 0;
    const missingTopupCodes = [];

    for (let operator of operators) {
      let a1Code = null;

      // 1. Try exact match
      if (a1TopupMappings[operator.name]) {
        a1Code = a1TopupMappings[operator.name];
      } else {
        // 2. Try partial match
        for (const [key, value] of Object.entries(a1TopupMappings)) {
          if (operator.name.includes(key) || key.includes(operator.name) || (operator.shortName && key.includes(operator.shortName))) {
            a1Code = value;
            break;
          }
        }
      }

      if (a1Code) {
        await ElectricityOperator.updateOne(
          { _id: operator._id },
          {
            $set: {
              planApi: { operatorCode: operator.operatorCode },
              a1Topup: { operatorCode: a1Code }
            }
          }
        );
        updatedCount++;
      } else {
        await ElectricityOperator.updateOne(
          { _id: operator._id },
          {
            $set: {
              planApi: { operatorCode: operator.operatorCode }
            }
          }
        );
        missingTopupCodes.push(operator.name);
      }
    }

    console.log(`\n=========================================================`);
    console.log(`MIGRATION COMPLETE`);
    console.log(`Total operators checked: ${operators.length}`);
    console.log(`Operators mapped with A1 Topup codes: ${updatedCount}`);
    if (missingTopupCodes.length > 0) {
      console.log(`\nOperators missing A1 Topup mapping (${missingTopupCodes.length}):`);
      missingTopupCodes.forEach(n => console.log(`- ${n}`));
    }
    console.log(`=========================================================\n`);
    
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

runMigration();
