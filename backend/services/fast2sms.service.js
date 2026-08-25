require('dotenv').config();
const axios = require('axios');

// Centralized WhatsApp Authentication Constants
const AUTH_MESSAGE_ID = process.env.FAST2SMS_AUTH_MESSAGE_ID || process.env.FAST2SMS_AUTH_TEMPLATE_ID || "27018";
const PHONE_NUMBER_ID = process.env.FAST2SMS_PHONE_NUMBER_ID || "1294250930429862";

class Fast2SMSService {
  constructor() {
    this.whatsappApiUrl = 'https://www.fast2sms.com/dev/whatsapp';
  }

  /**
   * Helper to fetch current environment configuration
   */
  _getConfig() {
    return {
      apiKey: process.env.FAST2SMS_API_KEY,
      authMessageId: AUTH_MESSAGE_ID,
      phoneNumberId: PHONE_NUMBER_ID,
      rechargeTemplateId: process.env.FAST2SMS_RECHARGE_TEMPLATE_ID || '26992',
      rechargeSuccessWhatsAppEnabled: process.env.FAST2SMS_RECHARGE_SUCCESS_ENABLED === 'true',
      brandName: process.env.FAST2SMS_BRAND_NAME || 'A1recharge',
      supportPhone: process.env.FAST2SMS_SUPPORT_PHONE || '8275366399',
    };
  }

  /**
   * Mask sensitive string for logs
   */
  _maskKey(key) {
    if (!key) return 'N/A';
    if (key.length <= 8) return '****';
    return `${key.substring(0, 4)}****${key.substring(key.length - 4)}`;
  }

  /**
   * Clean mobile number to standard 10-digit format
   */
  _cleanMobile(mobile) {
    if (!mobile) return '';
    let cleaned = String(mobile).replace(/\D/g, '');
    if (cleaned.length > 10 && cleaned.startsWith('91')) {
      cleaned = cleaned.slice(-10);
    }
    return cleaned;
  }

  /**
   * Send WhatsApp Authentication OTP Template matching @api/fast2sms SDK behavior
   * Endpoint: GET https://www.fast2sms.com/dev/whatsapp
   *
   * Working SDK Format:
   * variables_values: `${otp}%7CA1recharge%7C8275366399`
   *
   * @param {Object} params
   * @param {String} params.mobile - recipient mobile number
   * @param {String} params.otp - 6-digit generated OTP code
   */
  async sendAuthenticationTemplate({ mobile, otp }) {
    const startTime = Date.now();
    const config = this._getConfig();

    const targetMessageId = AUTH_MESSAGE_ID;
    const targetPhoneNumberId = PHONE_NUMBER_ID;

    // Strict Security & Integrity Guards
    if (!targetMessageId || String(targetMessageId).trim() === '') {
      throw new Error('[FAST2SMS GUARD ERROR] Authentication message_id is empty or missing.');
    }

    if (!targetPhoneNumberId || String(targetPhoneNumberId).trim() === '') {
      throw new Error('[FAST2SMS GUARD ERROR] Authentication phone_number_id is empty or missing.');
    }

    const cleanedMobile = this._cleanMobile(mobile);
    if (!cleanedMobile || cleanedMobile.length !== 10) {
      throw new Error('Invalid mobile number provided for Fast2SMS WhatsApp API.');
    }

    if (!config.apiKey) {
      console.error('[FAST2SMS ERROR] FAST2SMS_API_KEY is not configured in environment variables.');
      throw new Error('Fast2SMS API key is missing on backend server.');
    }

    const cleanOtp = String(otp).trim();
    const brandName = String(config.brandName).trim();
    const supportPhone = String(config.supportPhone).trim();

    if (!cleanOtp || !brandName || !supportPhone) {
      throw new Error(`Invalid template variable: OTP=${cleanOtp}, Brand=${brandName}, SupportPhone=${supportPhone}`);
    }

    // Exact variable mapping matching Fast2SMS SDK: {{1}} OTP | {{2}} A1recharge | {{3}} 8275366399 (Phone Number)
    // Encoded with %7C to match SDK request serialization
    const encodedVariables = `${cleanOtp}%7C${brandName}%7C${supportPhone}`;

    const headers = {
      'Authorization': config.apiKey,
      'accept': 'application/json',
    };

    const fullUrl = `${this.whatsappApiUrl}?message_id=${targetMessageId}&phone_number_id=${targetPhoneNumberId}&numbers=${cleanedMobile}&variables_values=${encodedVariables}`;

    console.log('════════════════════════════════════════════════════════════════');
    console.log('Message ID:\n' + targetMessageId + '\n');
    console.log('Phone Number ID:\n' + targetPhoneNumberId + '\n');
    console.log('Template:\nAuthentication OTP\n');
    console.log(`[FAST2SMS WHATSAPP TEMPLATE API REQUEST - SDK IDENTICAL]`);
    console.log(`- HTTP Method: GET`);
    console.log(`- Full Request URL: ${fullUrl}`);
    console.log(`- Headers:`, JSON.stringify({ Authorization: this._maskKey(config.apiKey), accept: 'application/json' }, null, 2));

    try {
      const response = await axios.get(fullUrl, {
        headers,
        timeout: 10000,
      });

      const duration = Date.now() - startTime;
      console.log(`[FAST2SMS WHATSAPP TEMPLATE API RESPONSE]`);
      console.log(`- HTTP Status: ${response.status} (${duration}ms)`);
      console.log(`- Complete Fast2SMS Response Body:`, JSON.stringify(response.data, null, 2));

      if (response.data && response.data.return === false) {
        console.error(`[FAST2SMS ERROR RESPONSE]:`, JSON.stringify(response.data, null, 2));
      }

      console.log('════════════════════════════════════════════════════════════════');

      return {
        success: response.data ? response.data.return !== false : true,
        data: response.data,
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      const errorMsg = error.response?.data?.message || error.response?.data || error.message;
      console.error(`[FAST2SMS WHATSAPP TEMPLATE API FAILURE] Duration: ${duration}ms, Error:`, errorMsg);
      if (error.response) {
        console.error(`- HTTP Status: ${error.response.status}`);
        console.error(`- Complete Response Body:`, JSON.stringify(error.response.data, null, 2));
      }
      console.log('════════════════════════════════════════════════════════════════');
      throw new Error(`Fast2SMS WhatsApp Delivery Failed: ${typeof errorMsg === 'object' ? JSON.stringify(errorMsg) : errorMsg}`);
    }
  }

  /**
   * Send WhatsApp Recharge Success Utility Template (Message ID: 26992) via Fast2SMS WhatsApp API
   */
  async sendRechargeSuccessTemplate({ customerName, mobileNumber, amount, operator, transactionId }) {
    const config = this._getConfig();

    if (!config.rechargeSuccessWhatsAppEnabled) {
      console.log('[WHATSAPP] Recharge success message disabled');
      console.log(`[WHATSAPP] Template recharge_success / ${config.rechargeTemplateId} was NOT sent`);
      return {
        success: true,
        skipped: true,
        message: 'Recharge success WhatsApp message disabled',
      };
    }

    const startTime = Date.now();
    const cleanedMobile = this._cleanMobile(mobileNumber);

    if (!cleanedMobile || cleanedMobile.length !== 10) {
      console.warn(`[FAST2SMS WARN] Skipping Recharge Success WhatsApp - invalid mobile: ${mobileNumber}`);
      return { success: false, reason: 'Invalid mobile' };
    }

    if (!config.apiKey) {
      console.warn('[FAST2SMS WARN] Skipping Recharge Success WhatsApp - FAST2SMS_API_KEY missing');
      return { success: false, reason: 'Missing API key' };
    }

    const name = (customerName || 'Valued Customer').replace(/\|/g, '');
    const txnId = String(transactionId || 'N/A').replace(/\|/g, '');
    const op = String(operator || 'Mobile Operator').replace(/\|/g, '');

    const encodedVariables = `${encodeURIComponent(name)}%7C${cleanedMobile}%7C${amount}%7C${encodeURIComponent(op)}%7C${encodeURIComponent(txnId)}`;

    const fullUrl = `${this.whatsappApiUrl}?message_id=${config.rechargeTemplateId}&phone_number_id=${PHONE_NUMBER_ID}&numbers=${cleanedMobile}&variables_values=${encodedVariables}`;

    console.log('════════════════════════════════════════════════════════════════');
    console.log(`[FAST2SMS RECHARGE SUCCESS REQUEST]`);
    console.log(`- HTTP Method: GET`);
    console.log(`- Full Request URL: ${fullUrl}`);

    try {
      const response = await axios.get(fullUrl, {
        headers: {
          'Authorization': config.apiKey,
          'accept': 'application/json',
        },
        timeout: 10000,
      });

      const duration = Date.now() - startTime;
      console.log(`[FAST2SMS RECHARGE SUCCESS RESPONSE] HTTP Status: ${response.status} (${duration}ms)`);
      console.log(`- Complete Fast2SMS Response Body:`, JSON.stringify(response.data, null, 2));
      console.log('════════════════════════════════════════════════════════════════');

      return {
        success: true,
        data: response.data,
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      const errorMsg = error.response?.data?.message || error.response?.data || error.message;
      console.error(`[FAST2SMS RECHARGE SUCCESS FAILURE] Duration: ${duration}ms, Error:`, errorMsg);
      console.log('════════════════════════════════════════════════════════════════');
      return {
        success: false,
        error: errorMsg,
      };
    }
  }

  /**
   * Send WhatsApp Welcome Message Template (a1_recharge_welcome_message)
   * WhatsApp Template ID: 2334539643620046
   * Fast2SMS Message ID: 30063
   * Variable 1: Customer/User Name
   *
   * @param {Object} params
   * @param {String} params.name - Onboarding User Name (e.g. Srujan)
   * @param {String} params.mobile - Recipient mobile number
   */
  async sendWelcomeTemplate({ name, mobile }) {
    const startTime = Date.now();
    const config = this._getConfig();
    const cleanedMobile = this._cleanMobile(mobile);

    const welcomeMessageId = process.env.FAST2SMS_WELCOME_MESSAGE_ID || '30063';
    const phoneNumberId = config.phoneNumberId || '1294250930429862';

    if (!cleanedMobile || cleanedMobile.length !== 10) {
      console.warn(`[WELCOME_WHATSAPP WARN] Invalid recipient mobile number: ${mobile}`);
      return { success: false, reason: 'Invalid mobile number' };
    }

    if (!config.apiKey) {
      console.warn('[WELCOME_WHATSAPP WARN] FAST2SMS_API_KEY missing in environment variables');
      return { success: false, reason: 'Missing Fast2SMS API key' };
    }

    const cleanName = String(name || 'Valued User').trim().replace(/\|/g, '');
    const encodedVariables = encodeURIComponent(cleanName);

    const fullUrl = `${this.whatsappApiUrl}?message_id=${welcomeMessageId}&phone_number_id=${phoneNumberId}&numbers=${cleanedMobile}&variables_values=${encodedVariables}`;

    const maskedMobile = cleanedMobile.length === 10 ? `******${cleanedMobile.slice(-4)}` : cleanedMobile;

    console.log('════════════════════════════════════════════════════════════════');
    console.log('[WELCOME_WHATSAPP]');
    console.log('Template: a1_recharge_welcome_message');
    console.log('WhatsApp Template ID: 2334539643620046');
    console.log(`Message ID: ${welcomeMessageId}`);
    console.log(`Recipient: ${maskedMobile}`);
    console.log(`Variable 1: ${cleanName}`);
    console.log('Sending welcome message...');

    try {
      const response = await axios.get(fullUrl, {
        headers: {
          'Authorization': config.apiKey,
          'accept': 'application/json',
        },
        timeout: 10000,
      });

      const duration = Date.now() - startTime;
      console.log(`[WELCOME_WHATSAPP] HTTP Status: ${response.status} (${duration}ms)`);
      console.log(`[WELCOME_WHATSAPP] Complete Response Body:`, JSON.stringify(response.data, null, 2));

      const isSuccess = response.data ? response.data.return !== false : true;
      if (isSuccess) {
        console.log('[WELCOME_WHATSAPP] Welcome message sent successfully');
      } else {
        console.warn('[WELCOME_WHATSAPP] Welcome message failed from provider response');
      }
      console.log('════════════════════════════════════════════════════════════════');

      return {
        success: isSuccess,
        data: response.data,
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      const errorMsg = error.response?.data?.message || error.response?.data || error.message;
      console.error(`[WELCOME_WHATSAPP] Welcome message failed (${duration}ms):`, typeof errorMsg === 'object' ? JSON.stringify(errorMsg) : errorMsg);
      console.log('════════════════════════════════════════════════════════════════');

      return {
        success: false,
        error: typeof errorMsg === 'object' ? JSON.stringify(errorMsg) : errorMsg,
      };
    }
  }
}

module.exports = new Fast2SMSService();
