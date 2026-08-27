const axios = require('axios');
const ProviderInterface = require('../Provider.interface');
const config = require('../../../config/a1topup.config');
const { normalizeStatus, logStatusCheckAudit } = require('../../../utils/statusNormalizer');

class A1TopupProvider extends ProviderInterface {
  constructor() {
    super();
    this.client = axios.create({
      baseURL: config.baseUrl,
      timeout: 10000, // 10s timeout
    });
  }

  /**
   * Health check validates configuration, reachability, and authentication.
   */
  async health() {
    try {
      if (!config.username || !config.password || !config.baseUrl) {
        throw new Error('A1 Topup configuration is incomplete.');
      }

      const response = await this.client.get('/recharge/balance', {
        params: {
          username: config.username,
          pwd: config.password,
          format: config.format,
        }
      });

      if (response.status === 200 && response.data) {
        // Depending on exact A1 Topup API, adapt error checking
        if (response.data.status === 'ERROR') {
            throw new Error(`Provider Auth Failed: ${response.data.message || 'Invalid credentials'}`);
        }

        return {
          success: true,
          status: 'healthy',
          message: 'Connected to A1 Topup successfully.',
          latency: response.headers['x-response-time'] || 'unknown',
        };
      }

      throw new Error(`Unexpected provider response status: ${response.status}`);
    } catch (error) {
      console.error('[A1TopupProvider] Health check failed:', error.message);
      return {
        success: false,
        status: 'unhealthy',
        message: error.response?.data?.message || error.message,
      };
    }
  }

  /**
   * Check balance of A1 Topup Wallet
   */
  async balance() {
    try {
      if (!config.username || !config.password || !config.baseUrl) {
        throw new Error('A1 Topup configuration is incomplete.');
      }

      const response = await this.client.get('/recharge/balance', {
        params: {
          username: config.username,
          pwd: config.password,
          format: config.format,
        }
      });

      if (response.status === 200 && response.data) {
        if (response.data.status === 'ERROR') {
            throw new Error(`Failed to fetch balance: ${response.data.message}`);
        }

        return {
          success: true,
          balance: parseFloat(response.data.balance || 0),
          currency: 'INR',
        };
      }

      throw new Error(`Unexpected provider response status: ${response.status}`);
    } catch (error) {
      console.error('[A1TopupProvider] Balance check failed:', error.message);
      throw new Error(`Provider Balance Error: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Fetch supported operators
   */
  async operators() {
    try {
      // Endpoint depends on actual A1 Topup docs. Assuming /api/operators
      const response = await this.client.get('/api/operators', {
        params: {
          username: config.username,
          password: config.password,
          format: config.format,
        }
      });

      if (response.status === 200 && response.data) {
        if (response.data.status === 'ERROR') {
            throw new Error(`Failed to fetch operators: ${response.data.message}`);
        }
        
        // Normalize response to generic format
        // Assumes provider returns an array or object containing operators
        return {
          success: true,
          data: response.data.operators || response.data,
        };
      }

      throw new Error(`Unexpected provider response status: ${response.status}`);
    } catch (error) {
      console.error('[A1TopupProvider] Fetch operators failed:', error.message);
      throw new Error(`Provider Operators Error: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Fetch plans for a given operator and circle
   */
  async plans(operatorCode, circleCode) {
    try {
      // Assuming /api/plans
      const response = await this.client.get('/api/plans', {
        params: {
          username: config.username,
          password: config.password,
          format: config.format,
          operator: operatorCode,
          circle: circleCode,
        }
      });

      if (response.status === 200 && response.data) {
        if (response.data.status === 'ERROR') {
            throw new Error(`Failed to fetch plans: ${response.data.message}`);
        }
        
        return {
          success: true,
          data: response.data.plans || response.data,
        };
      }

      throw new Error(`Unexpected provider response status: ${response.status}`);
    } catch (error) {
      console.error('[A1TopupProvider] Fetch plans failed:', error.message);
      throw new Error(`Provider Plans Error: ${error.response?.data?.message || error.message}`);
    }
  }
  /**
   * Execute Recharge
   */
  async recharge(options) {
    const { orderId, mobileNumber, amount, operatorCode, circleCode, serviceType, accountType } = options;
    const finalCircleCode = (circleCode && String(circleCode).trim() !== '') ? String(circleCode).trim() : '4';

    const payload = {
      username: config.username,
      pwd: config.password,
      format: config.format || 'json',
      number: mobileNumber,
      amount: amount,
      operatorcode: operatorCode,
      circlecode: finalCircleCode,
      orderid: orderId,
    };

    const safeParams = {
      endpoint: `${config.baseUrl}/recharge/api`,
      method: 'GET',
      username: config.username ? `${config.username.substring(0, 3)}***` : '***',
      pwd: '***',
      circlecode: finalCircleCode,
      operatorcode: operatorCode,
      number: mobileNumber ? `${mobileNumber.substring(0, 4)}***${mobileNumber.substring(mobileNumber.length - 2)}` : '***',
      amount: amount,
      orderid: orderId,
      format: config.format || 'json',
    };

    console.log('\n====================================================');
    console.log('[A1TOPUP LIVE HTTP REQUEST]');
    console.log(JSON.stringify(safeParams, null, 2));
    console.log('====================================================\n');

    const startTime = Date.now();
    try {
      // Most Indian topup APIs strictly use GET with query parameters
      const response = await this.client.get('/recharge/api', { params: payload });
      const elapsedMs = Date.now() - startTime;

      console.log('\n====================================================');
      console.log('[A1TOPUP LIVE HTTP RESPONSE]');
      console.log(`httpStatus=${response.status}`);
      console.log(`elapsedMs=${elapsedMs}ms`);
      console.log(`rawBody=${typeof response.data === 'object' ? JSON.stringify(response.data) : response.data}`);
      console.log('====================================================\n');

      return this._normalizeResponse(response.data, orderId);
    } catch (error) {
      const elapsedMs = Date.now() - startTime;
      console.error('\n====================================================');
      console.error('[A1TOPUP LIVE HTTP ERROR]');
      console.error(`elapsedMs=${elapsedMs}ms`);
      console.error(`errorType=${error.code || error.name}`);
      console.error(`message=${error.message}`);
      if (error.response) {
        console.error(`httpStatus=${error.response.status}`);
        console.error(`responseBody=${typeof error.response.data === 'object' ? JSON.stringify(error.response.data) : error.response.data}`);
      }
      console.error('====================================================\n');

      if (error.code === 'ECONNABORTED' || error.message.includes('timeout')) {
        return {
          success: false,
          status: 'PROVIDER_TIMEOUT',
          message: 'Provider timeout. Status unknown.',
          providerTransactionId: null,
          orderId: orderId,
        };
      }
      
      return {
        success: false,
        status: 'PROVIDER_UNREACHABLE',
        message: error.response?.data?.message || error.message,
        providerTransactionId: null,
        orderId: orderId,
      };
    }
  }

  /**
   * Fetch status of a transaction
   */
  async status(orderId) {
    try {
      const response = await this.client.get('/recharge/status', {
        params: {
          username: config.username,
          pwd: config.password,
          format: config.format,
          orderid: orderId, // Actually the docs say orderid
        }
      });

      console.log('\n====================================================');
      console.log('[A1TOPUP STATUS CHECK RAW RESPONSE]');
      console.log(`orderId=${orderId}`);
      console.log(`httpStatus=${response.status}`);
      console.log(`rawData=${JSON.stringify(response.data)}`);
      console.log('====================================================\n');

      return this._normalizeResponse(response.data, orderId);
    } catch (error) {
      console.error('[A1TopupProvider] Status check failed:', error.message);
      throw new Error(`Provider Status Error: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Helper to normalize A1 Topup response
   */
  _normalizeResponse(data, orderId = null) {
    if (!data || typeof data !== 'object') {
      data = {};
    }

    const rawStatusValue = data.status || data.Status || (data.error ? 'FAILED' : '');
    const norm = normalizeStatus(rawStatusValue);
    const status = norm.canonical; // 'SUCCESS', 'FAILED', 'PROCESSING', or 'UNKNOWN'

    let rawMessage = data.message || data.opid || data.errmsg || 'Processed';
    let cleanMessage = rawMessage;

    // Map dirty provider errors to clean UI errors
    if (status === 'FAILED') {
      if (rawMessage.includes('Invalid IP')) {
        cleanMessage = 'Provider network configuration error. Please contact admin.';
      } else if (rawMessage.includes('Insufficient Balance')) {
        cleanMessage = 'Provider temporarily unavailable due to low funds.';
      } else if (rawMessage.includes('Invalid Amount')) {
        cleanMessage = 'The selected plan amount is invalid for this operator/circle.';
      } else if (rawMessage.includes('Invalid Mobile')) {
        cleanMessage = 'The entered mobile number is invalid.';
      }
    }

    let providerTransactionId = data.txid || data.txnid || data.provider_id || null;
    if (
      providerTransactionId === 'N/A' ||
      providerTransactionId === 'null' ||
      providerTransactionId === 'undefined' ||
      providerTransactionId === 0 ||
      providerTransactionId === '0'
    ) {
      providerTransactionId = null;
    }

    const resolvedOrderId = data.orderid || data.client_id || orderId;

    logStatusCheckAudit({
      internalTransactionId: resolvedOrderId,
      providerTransactionId,
      orderId: resolvedOrderId,
      providerStatus: rawStatusValue || 'UNKNOWN',
      normalizedStatus: norm,
    });

    return {
      success: status === 'SUCCESS',
      status: status,
      globalStatus: norm.global,
      isTerminal: norm.isTerminal,
      message: cleanMessage,
      providerTransactionId,
      operatorReference: (status === 'FAILED') ? null : (data.opid || data.operator_ref || null),
      orderId: resolvedOrderId,
      rawResponse: data,
    };
  }
}

module.exports = new A1TopupProvider();
