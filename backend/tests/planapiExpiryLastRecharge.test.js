const mongoose = require('mongoose');
const planApiService = require('../services/planapi.service');
const { checkLastRecharge, checkRechargeExpiry } = require('../controllers/planapi.controller');

describe('PlanAPI Last Recharge & Recharge Expiry Acceptance Test Suite', () => {
  const airtelNumber = '9876543210';
  const bsnlNumber = '9421729714';

  test('TEST 1 — OPERATOR RESTRICTION: Identifies Airtel and VI as supported, BSNL & Jio as unsupported', () => {
    expect(planApiService.isOperatorSupportedForLastRechargeAndExpiry('AT')).toBe(true);
    expect(planApiService.isOperatorSupportedForLastRechargeAndExpiry('AIRTEL')).toBe(true);
    expect(planApiService.isOperatorSupportedForLastRechargeAndExpiry('VI')).toBe(true);
    expect(planApiService.isOperatorSupportedForLastRechargeAndExpiry('VF')).toBe(true);

    expect(planApiService.isOperatorSupportedForLastRechargeAndExpiry('BT')).toBe(false);
    expect(planApiService.isOperatorSupportedForLastRechargeAndExpiry('BSNL')).toBe(false);
    expect(planApiService.isOperatorSupportedForLastRechargeAndExpiry('JO')).toBe(false);
    expect(planApiService.isOperatorSupportedForLastRechargeAndExpiry('JIO')).toBe(false);
  });

  test('TEST 2 — UNSUPPORTED OPERATOR: Returns supported: false without making API call', async () => {
    const spy = jest.spyOn(planApiService, '_makeRequest');

    const result = await planApiService.checkLastRecharge(bsnlNumber, 'BT');
    expect(result.supported).toBe(false);
    expect(spy).not.toHaveBeenCalled();

    const expiryResult = await planApiService.checkRechargeExpiry(bsnlNumber, 'BT');
    expect(expiryResult.supported).toBe(false);
    expect(spy).not.toHaveBeenCalled();

    spy.mockRestore();
  });

  test('TEST 3 — PLANAPI CHECK LAST RECHARGE: Parses amount & rechargeDate for supported Airtel operator', async () => {
    const mockPlanApiResponse = {
      ERROR: '0',
      STATUS: '1',
      MOBILENO: airtelNumber,
      MESSAGE: 'Last Recharge Successfully Checked',
      Amount: '349',
      RechargeDate: '2026-08-23',
    };

    const spy = jest.spyOn(planApiService, '_makeRequest').mockResolvedValue(mockPlanApiResponse);

    const result = await planApiService.checkLastRecharge(airtelNumber, 'AT');

    expect(result.supported).toBe(true);
    expect(result.success).toBe(true);
    expect(result.data.amount).toBe('349');
    expect(result.data.rechargeDate).toBe('2026-08-23');

    spy.mockRestore();
  });

  test('TEST 4 — PLANAPI RECHARGE EXPIRY: Parses OUTGOING & INCOMING dates for supported VI operator', async () => {
    const mockExpiryResponse = {
      ERROR: '0',
      STATUS: '1',
      MOBILENO: airtelNumber,
      MESSAGE: 'Recharge Expiry Checked',
      OUTGOING: '2026-09-20',
      INCOMING: '2026-09-27',
    };

    const spy = jest.spyOn(planApiService, '_makeRequest').mockResolvedValue(mockExpiryResponse);

    const result = await planApiService.checkRechargeExpiry(airtelNumber, 'VI');

    expect(result.supported).toBe(true);
    expect(result.success).toBe(true);
    expect(result.data.outgoing).toBe('2026-09-20');
    expect(result.data.incoming).toBe('2026-09-27');

    spy.mockRestore();
  });

  test('TEST 5 — CONTROLLER SECURITY & DTO: Returns clean API response without exposing PlanAPI password', async () => {
    const mockPlanApiResponse = {
      ERROR: '0',
      STATUS: '1',
      MOBILENO: airtelNumber,
      MESSAGE: 'Success',
      Amount: '249',
      RechargeDate: '2026-08-23',
    };

    const spy = jest.spyOn(planApiService, '_makeRequest').mockResolvedValue(mockPlanApiResponse);

    const req = { query: { mobileNumber: airtelNumber, operatorCode: 'AT' } };
    let responseData;
    const res = {
      status: (code) => res,
      json: (data) => { responseData = data; return res; },
    };

    await checkLastRecharge(req, res);

    expect(responseData.supported).toBe(true);
    expect(responseData.success).toBe(true);
    expect(responseData.data.amount).toBe('249');
    // Ensure credentials are NOT leaked in output
    expect(JSON.stringify(responseData)).not.toContain('A1recharge');

    spy.mockRestore();
  });
});
