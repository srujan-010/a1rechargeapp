const axios = require('axios');

const PLANAPI_BASE_URL = process.env.PLANAPI_BASE_URL || 'https://planapi.in/api';
const PLANAPI_MEMBER_ID = process.env.PLANAPI_MEMBER_ID || '7315';
const PLANAPI_PASSWORD = process.env.PLANAPI_PASSWORD || 'A1recharge';

/**
 * Service to proxy requests to PlanAPI
 * Ensures PlanAPI only sees the backend's IP and credentials are kept secure.
 */
class PlanApiService {

  async _makeRequest(url) {
    // 1. Log OUTBOUND REQUEST
    const safeUrl = url.replace(PLANAPI_PASSWORD, '***').replace(PLANAPI_MEMBER_ID, '***');
    console.log('\n==================================================');
    console.log('[PlanAPI OUTBOUND REQUEST]');
    console.log(`URL: ${safeUrl}`);
    
    // Explicitly define headers to ensure NO client IP forwarding happens
    // We do NOT pass req.headers or any X-Forwarded-For headers
    const headers = {
      'Accept': 'application/json, text/plain, */*',
      'User-Agent': 'A1Recharge-Backend/1.0',
      'Connection': 'keep-alive'
    };
    console.log('Headers:', JSON.stringify(headers, null, 2));
    
    try {
      const response = await axios.get(url, { headers });
      
      // 2. Log RAW RESPONSE
      console.log('\n[PlanAPI RAW RESPONSE]');
      console.log(`Status: ${response.status} ${response.statusText}`);
      console.log('Headers:', JSON.stringify(response.headers, null, 2));
      console.log('Body:', typeof response.data === 'object' ? JSON.stringify(response.data).substring(0, 500) + '...' : response.data);
      console.log('==================================================\n');
      
      return response.data;
    } catch (error) {
      console.log('\n[PlanAPI OUTBOUND ERROR]');
      if (error.response) {
        console.log(`Status: ${error.response.status}`);
        console.log('Headers:', JSON.stringify(error.response.headers, null, 2));
        console.log('Body:', error.response.data);
      } else {
        console.log('Error Message:', error.message);
      }
      console.log('==================================================\n');
      throw error;
    }
  }
  
  async detectMobileOperator(mobile) {
    const url = `${PLANAPI_BASE_URL}/Mobile/OperatorFetchNew?ApiUserID=${PLANAPI_MEMBER_ID}&ApiPassword=${PLANAPI_PASSWORD}&Mobileno=${mobile}`;
    const data = await this._makeRequest(url);
    const isError = (data.ERROR !== '0' && data.ERROR !== undefined) || data.STATUS === '0' || data.status === '0' || data.status === false;
    return { success: !isError, data };
  }

  async fetchMobilePlans(operatorCode, circleCode) {
    const url = `${PLANAPI_BASE_URL}/Mobile/NewMobilePlans?apimember_id=${PLANAPI_MEMBER_ID}&api_password=${PLANAPI_PASSWORD}&operatorcode=${operatorCode}&cricle=${circleCode}`;
    const data = await this._makeRequest(url);
    const isError = data.ERROR !== '0' && data.ERROR !== undefined && data.STATUS !== '0' && data.STATUS !== '1';
    return { success: !isError, data };
  }

  async detectDthOperator(mobile) {
    const url = `${PLANAPI_BASE_URL}/Mobile/DthOperatorFetch?apimember_id=${PLANAPI_MEMBER_ID}&api_password=${PLANAPI_PASSWORD}&dth_number=${mobile}`;
    const data = await this._makeRequest(url);
    const isError = !data.Operator && !data.operator && !data.DthName;
    return { success: !isError, data };
  }

  async fetchDthCustomerInfo(mobile, operatorCode) {
    const url = `${PLANAPI_BASE_URL}/Mobile/DTHBasicDetails?apimember_id=${PLANAPI_MEMBER_ID}&api_password=${PLANAPI_PASSWORD}&mobile_no=${mobile}&Opcode=${operatorCode}`;
    const data = await this._makeRequest(url);
    const isError = data.ERROR !== '0' && data.ERROR !== undefined && data.STATUS !== '0' && data.STATUS !== '1';
    return { success: !isError, data };
  }

  async fetchDthPlans(operatorCode) {
    const url = `${PLANAPI_BASE_URL}/Mobile/DthPlans?apimember_id=${PLANAPI_MEMBER_ID}&api_password=${PLANAPI_PASSWORD}&operatorcode=${operatorCode}`;
    const data = await this._makeRequest(url);
    const isError = data.ERROR !== '0' && data.ERROR !== undefined && data.STATUS !== '0' && data.STATUS !== '1';
    return { success: !isError, data };
  }
}

module.exports = new PlanApiService();
