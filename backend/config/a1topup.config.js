require('dotenv').config();

module.exports = {
  baseUrl: process.env.A1TOPUP_BASE_URL || 'https://business.a1topup.com',
  username: process.env.A1TOPUP_USERNAME,
  password: process.env.A1TOPUP_PASSWORD,
  format: process.env.A1TOPUP_FORMAT || 'json',
};
