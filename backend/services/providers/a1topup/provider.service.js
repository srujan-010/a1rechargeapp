const axios = require('axios');
const ProviderInterface = require('../Provider.interface');
const config = require('../../../config/a1topup.config');

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
    const { orderId, mobileNumber, amount, operatorCode, circleCode } = options;
    
    try {
      const payload = {
        username: config.username,
        pwd: config.password,
        format: config.format,
        number: mobileNumber,
        amount: amount,
        operatorcode: operatorCode,
        circlecode: circleCode,
        orderid: orderId,
      };

      console.log('\n--- A1 TOPUP RECHARGE API LOG ---');
      console.log(`URL: ${config.baseUrl}/recharge/api`);
      console.log(`Method: GET`);
      console.log(`Payload: ${JSON.stringify({ ...payload, pwd: '***' })}`);

      // Most Indian topup APIs strictly use GET with query parameters
      const response = await this.client.get('/recharge/api', { params: payload });

      console.log(`Status Code: ${response.status}`);
      console.log(`Raw Response: ${JSON.stringify(response.data)}`);
      console.log('---------------------------------\n');

      return this._normalizeResponse(response.data, orderId);
    } catch (error) {
      console.error('[A1TopupProvider] Recharge failed:', error.message);
      // Determine if error is a timeout or reachability issue to mark as PENDING instead of FAILED
      if (error.code === 'ECONNABORTED' || error.message.includes('timeout')) {
        return {
          success: false,
          status: 'PENDING',
          message: 'Provider timeout. Status unknown.',
          providerTransactionId: null,
          orderId: orderId,
        };
      }
      
      return {
        success: false,
        status: 'FAILED',
        message: error.response?.data?.message || error.message,
        providerTransactionId: null,
        orderId: orderId,
      };
    }
  }

  /**
   * Fetch status of a transaction
   */
  async status(providerTransactionId) {
    try {
      const response = await this.client.get('/recharge/status', {
        params: {
          username: config.username,
          pwd: config.password,
          format: config.format,
          orderid: providerTransactionId, // Actually the docs say orderid
        }
      });

      return this._normalizeResponse(response.data);
    } catch (error) {
      console.error('[A1TopupProvider] Status check failed:', error.message);
      throw new Error(`Provider Status Error: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Helper to normalize A1 Topup response
   */
  _normalizeResponse(data, orderId = null) {
    // This maps A1 Topup's specific fields to our generic format
    let status = 'PENDING';
    
    // Some APIs use lowercase, some uppercase keys.
    const rawStatusValue = data.status || data.Status || '';
    const rawStatus = String(rawStatusValue).toUpperCase().trim();
    
    if (rawStatus === 'SUCCESS' || rawStatus === 'COMPLETED') {
      status = 'SUCCESS';
    } else if (rawStatus === 'FAILED' || rawStatus === 'ERROR' || rawStatus === 'FAILURE') {
      status = 'FAILED';
    } else {
      // Anything else is PENDING (Timeout, Unknown, etc)
      status = 'PENDING';
    }

    let rawMessage = data.message || data.opid || 'Processed';
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

    return {
      success: status === 'SUCCESS',
      status: status,
      message: cleanMessage,
      providerTransactionId: data.txid || data.txnid || data.provider_id || null,
      operatorReference: (status === 'FAILED') ? null : (data.opid || data.operator_ref || null), // Only map opid to operatorReference if SUCCESS. Otherwise it's an error message.
      orderId: data.orderid || data.client_id || orderId,
    };
  }
}

module.exports = new A1TopupProvider();
