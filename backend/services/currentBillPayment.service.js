const axios = require('axios');
const config = require('../config/a1topup.config');

class CurrentBillPaymentService {
  constructor() {
    this.client = axios.create({
      baseURL: config.baseUrl,
      timeout: 10000,
    });
  }

  /**
   * Execute Current Bill Payment (Electricity, Gas, FASTag)
   * This service is STRICTLY isolated from Mobile/DTH recharge logic.
   * It intentionally DOES NOT include or process `circlecode`.
   */
  async payBill(options) {
    const { orderId, consumerIdentifier, amount, operatorCode, serviceType } = options;

    try {
      const payload = {
        username: config.username,
        pwd: config.password,
        format: config.format || 'json',
        number: consumerIdentifier,
        amount: amount,
        operatorcode: operatorCode,
        orderid: orderId,
      };

      const safeParams = { ...payload, pwd: '***' };
      const fullUrl = `${config.baseUrl}/recharge/api?username=${payload.username}&pwd=***&format=${payload.format}&number=${payload.number}&amount=${payload.amount}&operatorcode=${payload.operatorcode}&orderid=${payload.orderid}`;

      console.log('\n==================================================');
      console.log(`[LOG 4] Calling https://business.a1topup.com/recharge/api`);
      console.log(`[LOG 5] Outbound Request (masked):`);
      console.log(`  Full URL: ${fullUrl}`);
      console.log(`  operatorcode: ${payload.operatorcode}`);
      console.log(`  number: ${payload.number}`);
      console.log(`  amount: ${payload.amount}`);
      console.log(`  orderid: ${payload.orderid}`);
      console.log(`  format: ${payload.format}`);

      const response = await this.client.get('/recharge/api', { params: payload });

      console.log(`\n[LOG 6] FULL RAW RESPONSE FROM A1 TOPUP:`);
      console.log(`  HTTP Status: ${response.status}`);
      console.log(`  Body: ${typeof response.data === 'object' ? JSON.stringify(response.data, null, 2) : response.data}`);
      console.log('==================================================\n');

      return this._normalizeResponse(response.data, orderId);
    } catch (error) {
      console.error(`\n[LOG 7] AXIOS EXCEPTION OCCURRED WHEN CALLING A1 TOPUP RECHARGE API:`);
      console.error(`  Error Message: ${error.message}`);
      if (error.response) {
        console.error(`  HTTP Status Code: ${error.response.status}`);
        console.error(`  Headers: ${JSON.stringify(error.response.headers, null, 2)}`);
        console.error(`  Response Body: ${typeof error.response.data === 'object' ? JSON.stringify(error.response.data, null, 2) : error.response.data}`);
      }
      console.error(`  Stack Trace: ${error.stack}`);
      console.error('==================================================\n');

      // Determine if error is a timeout or reachability issue
      if (error.code === 'ECONNABORTED' || error.message.includes('timeout')) {
        return {
          success: false,
          status: 'PENDING',
          message: 'Provider timeout. Status unknown. Check transaction history later.',
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
   * Helper to normalize A1 Topup response
   */
  _normalizeResponse(data, orderId = null) {
    let status = 'PENDING';
    
    if (typeof data === 'string') {
      const lowerData = data.toLowerCase();
      if (lowerData.includes('invalid order id')) {
        return {
          success: false,
          status: 'FAILED',
          message: 'The transaction does not exist on provider. Request was never submitted.',
          providerTransactionId: null,
          operatorReference: null,
          orderId: orderId,
          rawResponse: data,
        };
      }
      
      return {
        success: false,
        status: lowerData.includes('success') ? 'SUCCESS' : (lowerData.includes('fail') || lowerData.includes('error') || lowerData.includes('invalid') ? 'FAILED' : 'PENDING'),
        message: data,
        providerTransactionId: null,
        operatorReference: null,
        orderId: orderId,
        rawResponse: data,
      };
    }

    const rawStatusValue = data.status || data.Status || '';
    const rawStatus = String(rawStatusValue).toUpperCase().trim();
    
    if (rawStatus === 'SUCCESS' || rawStatus === 'COMPLETED') {
      status = 'SUCCESS';
    } else if (rawStatus === 'FAILED' || rawStatus === 'ERROR' || rawStatus === 'FAILURE') {
      status = 'FAILED';
    } else {
      status = 'PENDING';
    }

    let rawMessage = data.message || data.opid || 'Processed';
    let cleanMessage = rawMessage;

    if (status === 'FAILED') {
      if (rawMessage.includes('Invalid IP')) {
        cleanMessage = 'Provider network configuration error. Please contact admin.';
      } else if (rawMessage.includes('Insufficient Balance')) {
        cleanMessage = 'Provider temporarily unavailable due to low funds.';
      } else if (rawMessage.includes('Invalid Amount')) {
        cleanMessage = 'The payment amount is invalid for this bill/operator.';
      } else if (rawMessage.includes('Invalid')) {
        cleanMessage = 'The consumer details are invalid or provider is down.';
      }
    }

    return {
      success: status === 'SUCCESS',
      status: status,
      message: cleanMessage,
      providerTransactionId: data.txid || data.txnid || data.provider_id || null,
      operatorReference: (status === 'FAILED') ? null : (data.opid || data.operator_ref || null),
      orderId: data.orderid || data.client_id || orderId,
      rawResponse: data,
    };
  }

  /**
   * EXECUTOR with Wallet and Transaction integration
   */
  async executePayment(options) {
    const walletService = require('./wallet/wallet.service');
    const ledgerService = require('./ledger/ledger.service');
    const RechargeTransaction = require('../models/RechargeTransaction');

    const { user, mpin, consumerIdentifier, amount, operatorCode, serviceType, orderIdPrefix = 'CB' } = options;

    if (!mpin) throw new Error('Missing MPIN');

    const isMatch = await user.matchMpin(mpin);
    if (!isMatch) throw new Error('Invalid MPIN');

    const orderId = `${orderIdPrefix}${Date.now()}`;

    console.log('\n==================================================');
    console.log(`[LOG 2] Generated internal transactionId / orderId: ${orderId}`);
    console.log(`[LOG 3] Generated provider orderId: ${orderId}`);
    console.log(`  User: ${user._id}`);
    console.log(`  Consumer Identifier: ${consumerIdentifier}`);
    console.log(`  Amount (₹): ${amount}`);
    console.log(`  Operator Code: ${operatorCode}`);
    console.log('==================================================\n');

    // Step 1: Reserve wallet BEFORE calling A1 Topup
    await walletService.reserveAmount(user._id, amount);
    console.log(`[PAYMENT EXECUTOR] Wallet reserved ₹${amount} for user ${user._id}`);

    let paymentResponse;
    try {
      // Step 2: Call A1 Topup FIRST, before creating DB record
      console.log(`[PAYMENT EXECUTOR] Calling A1 Topup with orderId: ${orderId}`);
      paymentResponse = await this.payBill({
        orderId,
        consumerIdentifier,
        amount,
        operatorCode,
        serviceType
      });
    } catch (apiErr) {
      // A1 Topup call itself threw an exception — release wallet and return error immediately
      console.error(`[PAYMENT EXECUTOR] ✖ A1 Topup API threw exception. Releasing wallet. Error: ${apiErr.message}`);
      await walletService.releaseReservation(user._id, amount);
      throw apiErr;
    }

    // Step 3: Check if A1 Topup explicitly failed — if so, release wallet and return error immediately
    if (!paymentResponse.success && paymentResponse.status === 'FAILED') {
      console.error(`[PAYMENT EXECUTOR] ✖ A1 Topup returned FAILED. Releasing wallet. Reason: ${paymentResponse.message}`);
      await walletService.releaseReservation(user._id, amount);
      // Return the failure immediately WITHOUT creating any MongoDB record
      return paymentResponse;
    }

    // Step 4: A1 Topup accepted the request (SUCCESS or PENDING). ONLY NOW update/create MongoDB record.
    console.log(`[LOG 8] Provider responded with status '${paymentResponse.status}'. Updating MongoDB...`);
    const a1TopupOrderId = paymentResponse.orderId || orderId;
    console.log(`  Saved orderId in MongoDB: ${orderId}`);
    console.log(`  orderId returned by A1 Topup: ${a1TopupOrderId}`);

    const transaction = await RechargeTransaction.create({
      orderId,         // We always use OUR orderId for lookups
      userId: user._id,
      providerName: 'A1Topup',
      mobileNumber: consumerIdentifier,
      amount: amount,
      operatorCode: operatorCode,
      circleCode: 'N/A',
      status: paymentResponse.status === 'SUCCESS' ? 'SUCCESS' : 'PENDING',
      reservedAmount: amount,
      serviceType: serviceType.toLowerCase(),
      providerTransactionId: paymentResponse.providerTransactionId || null,
      operatorReference: paymentResponse.operatorReference || null,
    });

    console.log(`[LOG 8 COMPLETE] ✔ Transaction saved in MongoDB. _id: ${transaction._id}, orderId: ${transaction.orderId}, status: ${transaction.status}`);

    // Step 5: If already SUCCESS, commit wallet and ledger immediately
    if (paymentResponse.success) {
      await walletService.commitReservation(user._id, amount);
      await ledgerService.createTransaction(
        user._id,
        'DEBIT',
        amount,
        `${serviceType} Payment - ${consumerIdentifier}`,
        orderId,
        'RECHARGE',
        transaction._id
      );
      console.log(`[PAYMENT EXECUTOR] ✔ Wallet committed and ledger entry created (immediate SUCCESS).`);
    } else {
      console.log(`[PAYMENT EXECUTOR] Transaction is PENDING. Polling will begin. orderId for status check: ${orderId}`);
    }

    return {
      ...paymentResponse,
      orderId,  // Always return OUR orderId so Flutter uses it consistently in status polls
    };
  }

  /**
   * Check Status with Wallet and Transaction integration
   */
  async checkStatus(orderId) {
    const walletService = require('./wallet/wallet.service');
    const ledgerService = require('./ledger/ledger.service');
    const RechargeTransaction = require('../models/RechargeTransaction');

    const transaction = await RechargeTransaction.findOne({ orderId });
    if (!transaction) {
      throw new Error(`Transaction with orderId ${orderId} not found`);
    }

    // If already terminal, just return it
    if (transaction.status === 'SUCCESS' || transaction.status === 'FAILED') {
      return {
        success: transaction.status === 'SUCCESS',
        status: transaction.status,
        message: transaction.status === 'SUCCESS' ? 'Processed' : (transaction.failureReason || 'Failed'),
        providerTransactionId: transaction.providerTransactionId,
        orderId: transaction.orderId
      };
    }

    try {
      // Poll A1 Topup Status API
      const payload = {
        username: config.username,
        pwd: config.password,
        format: config.format || 'json',
        orderid: orderId,
      };

      const safeParams = { ...payload, pwd: '***' };
      const fullUrl = `https://business.a1topup.com/recharge/status?username=${payload.username}&pwd=***&orderid=${orderId}&format=${payload.format}`;
      
      console.log('\n==================================================');
      console.log(`[STATUS CHECK] OUTBOUND REQUEST for OrderId: ${orderId}`);
      console.log(`Incoming transactionId: ${orderId}`);
      console.log(`Stored orderId: ${transaction.orderId}`);
      console.log(`Calling A1Topup Status API...`);
      console.log(`Full provider URL: ${fullUrl}`);

      const response = await this.client.get('/recharge/status', { params: payload });

      console.log(`\n[STATUS CHECK] Provider Response`);
      console.log(`Status: ${response.status}`);
      console.log(typeof response.data === 'object' ? JSON.stringify(response.data, null, 2) : response.data);
      console.log(`Previous MongoDB status: ${transaction.status}`);

      const statusResponse = this._normalizeResponse(response.data, orderId);

      if (statusResponse.status === 'SUCCESS') {
        transaction.status = 'SUCCESS';
        transaction.providerTransactionId = statusResponse.providerTransactionId;
        transaction.operatorReference = statusResponse.operatorReference;
        await transaction.save();

        await walletService.commitReservation(transaction.userId, transaction.amount);
        
        await ledgerService.createTransaction(
          transaction.userId,
          'DEBIT',
          transaction.amount,
          `${transaction.serviceType} Payment - ${transaction.mobileNumber}`,
          transaction.orderId,
          'RECHARGE',
          transaction._id
        );
      } else if (statusResponse.status === 'FAILED') {
        transaction.status = 'FAILED';
        transaction.failureReason = statusResponse.message;
        transaction.providerTransactionId = statusResponse.providerTransactionId;
        await transaction.save();

        await walletService.releaseReservation(transaction.userId, transaction.amount);
      } else {
        // Still PENDING
        if (statusResponse.providerTransactionId && !transaction.providerTransactionId) {
           transaction.providerTransactionId = statusResponse.providerTransactionId;
           await transaction.save();
        }
      }

      console.log(`Updated MongoDB status: ${transaction.status}`);
      console.log(`Returned status: ${statusResponse.status}`);
      console.log('==================================================\n');

      return statusResponse;
    } catch (err) {
      console.error(`[STATUS CHECK] Error polling status for ${orderId}:`, err.message);
      return {
        success: false,
        status: 'PENDING',
        message: 'Status check failed due to network error.',
        orderId: orderId
      };
    }
  }
}

module.exports = new CurrentBillPaymentService();
