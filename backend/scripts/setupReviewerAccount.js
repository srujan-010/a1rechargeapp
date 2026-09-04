require('dotenv').config();
const mongoose = require('mongoose');
const reviewerService = require('../services/reviewer.service');
const connectDB = require('../config/db');

async function main() {
  console.log('════════════════════════════════════════════════════════════════');
  console.log('[GOOGLE PLAY REVIEWER ACCOUNT SETUP & AUDIT]');
  console.log('════════════════════════════════════════════════════════════════');

  const phone = process.env.GOOGLE_PLAY_REVIEWER_PHONE;
  const otp = process.env.GOOGLE_PLAY_REVIEWER_OTP;
  const pin = process.env.GOOGLE_PLAY_REVIEWER_PIN;

  if (!phone || String(phone).trim().length < 10) {
    console.error('✖ ERROR: GOOGLE_PLAY_REVIEWER_PHONE is missing or invalid in environment.');
    console.error('  Please set GOOGLE_PLAY_REVIEWER_PHONE=9XXXXXXXXX in your .env file.');
    process.exit(1);
  }

  if (!otp || String(otp).trim().length < 4) {
    console.error('✖ ERROR: GOOGLE_PLAY_REVIEWER_OTP is missing in environment.');
    console.error('  Please set a secret 6-digit OTP (e.g. GOOGLE_PLAY_REVIEWER_OTP=951753) in your .env file.');
    process.exit(1);
  }

  if (!pin || String(pin).trim().length < 4) {
    console.warn('⚠ WARNING: GOOGLE_PLAY_REVIEWER_PIN is not configured. Setting default test PIN is recommended.');
  }

  try {
    await connectDB();
    console.log('✔ Connected to MongoDB successfully.');

    const cleanedPhone = reviewerService.getReviewerPhone();
    console.log(`Checking database for conflicts on phone: ******${cleanedPhone.slice(-4)}`);

    // 1. Multi-format conflict check
    const existing = await reviewerService.checkExistingUserConflict(cleanedPhone);
    if (existing) {
      console.log(`✔ Found existing reviewer test account: ID=${existing._id}, RetailerID=${existing.retailerId}`);
    } else {
      console.log('✔ No existing account found. Creating new isolated reviewer test account...');
    }

    // 2. Ensure reviewer account, test wallet, and test KYC
    const user = await reviewerService.ensureReviewerAccount();

    console.log('\n✔ Reviewer Account Verified & Ready:');
    console.log(`  - User ID: ${user._id}`);
    console.log(`  - Retailer ID: ${user.retailerId}`);
    console.log(`  - Role: ${user.role} (Normal retailer privileges)`);
    console.log(`  - Account Type: ${user.accountType}`);
    console.log(`  - Is Onboarded: ${user.isOnboarded}`);
    console.log(`  - Is Test Account: ${user.isTestAccount}`);
    console.log(`  - Security PIN Set: ${!!user.securityPinHash}`);
    console.log(`  - Wallet MPIN Set: ${!!user.walletMpinHash}`);
    console.log('════════════════════════════════════════════════════════════════');
    console.log('Safe reviewer account verification complete.');
    process.exit(0);
  } catch (error) {
    console.error('\n✖ FAILED:', error.message);
    process.exit(1);
  }
}

main();
