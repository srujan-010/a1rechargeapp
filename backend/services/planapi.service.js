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
      console.log('Body:', typeof response.data === 'object' ? JSON.stringify(response.data, null, 2) : response.data);
      console.log('==================================================\n');
      
      return response.data;
    } catch (error) {
      console.log('\n[PlanAPI OUTBOUND ERROR]');
      if (error.response) {
        console.log(`Status: ${error.response.status}`);
        console.log('Headers:', JSON.stringify(error.response.headers, null, 2));
        console.log('Body:', typeof error.response.data === 'object' ? JSON.stringify(error.response.data, null, 2) : error.response.data);
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

  async fetchElectricityBill(operatorCode, parameters) {
    console.log('\n==================================================');
    console.log('[PlanAPI SERVICE] fetchElectricityBill Called');
    console.log('Operator Code:', operatorCode);
    console.log('Parameters from Flutter:', parameters);

    const billNumber = parameters.bill_number || parameters.consumer_number || parameters.account_id || parameters.service_number || Object.values(parameters)[0] || '';
    const optional1 = parameters.optional1 || parameters.Optional1 || '';
    const optional2 = parameters.optional2 || parameters.Optional2 || '';
    const optional3 = parameters.optional3 || parameters.Optional3 || '';
    
    // As per requirement:
    // operator_code = 131
    // bill_number = 476020101151
    // Omit Optional1, Optional2, Optional3 if they are empty
    let url = `${PLANAPI_BASE_URL}/Mobile/ElectricityBillFetch?apimember_id=${PLANAPI_MEMBER_ID}&api_password=${PLANAPI_PASSWORD}&operator_code=${operatorCode}&bill_number=${encodeURIComponent(billNumber)}`;
    
    // Only append if they exist and are not empty strings
    if (optional1 && optional1.trim() !== '') url += `&Optional1=${encodeURIComponent(optional1)}`;
    if (optional2 && optional2.trim() !== '') url += `&Optional2=${encodeURIComponent(optional2)}`;
    if (optional3 && optional3.trim() !== '') url += `&Optional3=${encodeURIComponent(optional3)}`;

    console.log('Parameter Mapping:');
    console.log(`- operator_code: ${operatorCode}`);
    console.log(`- bill_number: ${billNumber}`);
    if (optional1 && optional1.trim() !== '') console.log(`- Optional1: ${optional1}`);
    if (optional2 && optional2.trim() !== '') console.log(`- Optional2: ${optional2}`);
    if (optional3 && optional3.trim() !== '') console.log(`- Optional3: ${optional3}`);

    const urlObj = new URL(url);
    const searchParams = new URLSearchParams(urlObj.search);
    searchParams.set('api_password', '***');
    searchParams.set('apimember_id', '***');
    
    console.log(`[PlanAPI OUTBOUND] Final Query Parameters: ${searchParams.toString()}`);
    console.log(`[PlanAPI OUTBOUND] Final URL: ${urlObj.origin}${urlObj.pathname}?${searchParams.toString()}`);
    console.log('HTTP Method: GET');
    console.log('==================================================\n');

    try {
      const data = await this._makeRequest(url);
      
      console.log('\n[PlanAPI SERVICE] Parsed JSON Response:', data);
      
      const isError = data.ERROR !== '0' && data.ERROR !== undefined && data.STATUS !== '0' && data.STATUS !== '1';
      return { success: !isError, data };
    } catch (error) {
      console.log('\n[PlanAPI SERVICE] Exception Thrown in fetchElectricityBill:', error.message);
      throw error;
    }
  }
  async fetchGasBill(operatorCode, parameters) {
    console.log('\n==================================================');
    console.log('[PlanAPI SERVICE] fetchGasBill Called');
    console.log('Operator Code:', operatorCode);
    console.log('Parameters from Flutter:', parameters);

    const billNumber = parameters.bill_number || parameters.consumer_number || parameters.account_id || Object.values(parameters)[0] || '';
    
    let url = `${PLANAPI_BASE_URL}/Mobile/GasInfoFetch?apimember_id=${PLANAPI_MEMBER_ID}&api_password=${PLANAPI_PASSWORD}&operator_code=${operatorCode}&ConsumerNo=${encodeURIComponent(billNumber)}`;

    try {
      const data = await this._makeRequest(url);
      
      console.log('\n[PlanAPI SERVICE] Parsed JSON Response:', data);
      
      const isError = data.ERROR !== '0' && data.ERROR !== undefined && data.STATUS !== '0' && data.STATUS !== '1';
      return { success: !isError, data };
    } catch (error) {
      console.log('\n[PlanAPI SERVICE] Exception Thrown in fetchGasBill:', error.message);
      throw error;
    }
  }

  async fetchFastagDetails(operatorCode, parameters) {
    console.log('\n==================================================');
    console.log('[PlanAPI SERVICE] fetchFastagDetails Called');
    console.log('Operator Code:', operatorCode);
    console.log('Parameters from Flutter:', parameters);

    const vehicleNumber = parameters.vehicleNumber || parameters.vehicle_number || Object.values(parameters)[0] || '';
    
    let url = `${PLANAPI_BASE_URL}/Mobile/FastagInfoFetch?apimember_id=${PLANAPI_MEMBER_ID}&api_password=${PLANAPI_PASSWORD}&operator_code=${operatorCode}&vehicle_number=${encodeURIComponent(vehicleNumber)}`;

    try {
      const data = await this._makeRequest(url);
      
      console.log('\n[PlanAPI SERVICE] Parsed JSON Response:', data);
      
      const isError = data.ERROR !== '0' && data.ERROR !== undefined && data.STATUS !== '0' && data.STATUS !== '1';
      return { success: !isError, data };
    } catch (error) {
      console.log('\n[PlanAPI SERVICE] Exception Thrown in fetchFastagDetails:', error.message);
      throw error;
    }
  }
}

module.exports = new PlanApiService();
