const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
dotenv.config({ path: path.join(__dirname, '../.env') });

const operatorSchema = new mongoose.Schema({
  name: String,
  shortName: String,
  operatorCode: String,
  serviceType: String,
});
const Operator = mongoose.model('Operator', operatorSchema, 'operators');

const electricityOperatorSchema = new mongoose.Schema({
  name: String,
  shortName: String,
  operatorCode: String,
  state: String
});
const ElectricityOperator = mongoose.model('ElectricityOperator', electricityOperatorSchema, 'electricity_operators');

async function main() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    const ops = await Operator.find({});
    
    console.log("=== MOBILE PREPAID ===");
    ops.filter(o => o.serviceType === 'prepaid').forEach(o => {
      console.log(`${o.name.padEnd(20)}: ${o.operatorCode}`);
    });
    
    console.log("\n=== MOBILE POSTPAID ===");
    ops.filter(o => o.serviceType === 'postpaid').forEach(o => {
      console.log(`${o.name.padEnd(20)}: ${o.operatorCode}`);
    });

    console.log("\n=== DTH ===");
    ops.filter(o => o.serviceType === 'dth').forEach(o => {
      console.log(`${o.name.padEnd(20)}: ${o.operatorCode}`);
    });

    const eOps = await ElectricityOperator.find({});
    console.log("\n=== ELECTRICITY (Sample of 10) ===");
    eOps.slice(0, 10).forEach(o => {
      console.log(`${o.name.substring(0, 40).padEnd(42)}: ${o.operatorCode} (${o.state})`);
    });
    console.log(`... and ${eOps.length - 10} more electricity operators`);

    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}
main();
