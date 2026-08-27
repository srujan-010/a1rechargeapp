const {
  getA1TopupOperatorCode,
  getPlansApiOperatorCode,
} = require('../utils/operatorResolver');
const planApiService = require('../services/planapi.service');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');

describe('PlanAPI & A1Topup Strict Operator Isolation Test Suite', () => {
  test('TEST 1 — PLANSAPI OPERATOR RESOLUTION: Returns explicit PlansAPI operator code', () => {
    const airtelOp = { name: 'Airtel', a1TopupCode: 'A', plansApiCode: 'AT' };
    const jioOp = { name: 'Reliance Jio', a1TopupCode: 'RC', plansApiCode: 'RJ' };
    const viOp = { name: 'Vodafone', a1TopupCode: 'V', plansApiCode: 'VI' };
    const bsnlOp = { name: 'BSNL TOPUP', a1TopupCode: 'BT', plansApiCode: 'CG' };

    expect(getPlansApiOperatorCode(airtelOp)).toBe('AT');
    expect(getPlansApiOperatorCode(jioOp)).toBe('RJ');
    expect(getPlansApiOperatorCode(viOp)).toBe('VI');
    expect(getPlansApiOperatorCode(bsnlOp)).toBe('CG');
  });

  test('TEST 2 — A1TOPUP OPERATOR RESOLUTION: Returns explicit A1Topup operator code', () => {
    const airtelOp = { name: 'Airtel', a1TopupCode: 'A', plansApiCode: 'AT' };
    const jioOp = { name: 'Reliance Jio', a1TopupCode: 'RC', plansApiCode: 'RJ' };
    const viOp = { name: 'Vodafone', a1TopupCode: 'V', plansApiCode: 'VI' };
    const bsnlOp = { name: 'BSNL TOPUP', a1TopupCode: 'BT', plansApiCode: 'CG' };

    expect(getA1TopupOperatorCode(airtelOp)).toBe('A');
    expect(getA1TopupOperatorCode(jioOp)).toBe('RC');
    expect(getA1TopupOperatorCode(viOp)).toBe('V');
    expect(getA1TopupOperatorCode(bsnlOp)).toBe('BT');
  });

  test('TEST 3 — STRICT VALIDATION: Missing provider code throws explicit validation error', () => {
    const invalidOp = { name: 'Unknown Operator' };

    expect(() => getA1TopupOperatorCode(invalidOp)).toThrow(/MISSING_A1TOPUP_CODE/);
    expect(() => getPlansApiOperatorCode(invalidOp)).toThrow(/MISSING_PLANS_API_CODE/);
  });

  test('TEST 4 — SERVICE METHOD ISOLATION: PlanApiService and A1TopupProvider methods remain isolated', () => {
    expect(typeof planApiService.fetchMobilePlans).toBe('function');
    expect(typeof planApiService.checkLastRecharge).toBe('function');
    expect(planApiService.recharge).toBeUndefined();

    expect(typeof a1TopupProvider.recharge).toBe('function');
    expect(typeof a1TopupProvider.balance).toBe('function');
    expect(a1TopupProvider.fetchMobilePlans).toBeUndefined();
  });
});
