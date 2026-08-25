const {
  resolvePlansApiOperatorCode,
  resolveA1TopupOperatorCode,
  PLANSAPI_TO_CANONICAL,
  CANONICAL_TO_PLANSAPI,
  CANONICAL_TO_A1TOPUP,
} = require('../utils/operatorMapper');
const planApiService = require('../services/planapi.service');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');

describe('PlanAPI & A1Topup Isolation Acceptance Test Suite', () => {
  test('TEST 1 — PLANSAPI OPERATOR RESOLUTION: Canonical codes resolve to numeric PlansAPI codes', () => {
    expect(resolvePlansApiOperatorCode('AT')).toBe('2');
    expect(resolvePlansApiOperatorCode('AIRTEL')).toBe('2');
    expect(resolvePlansApiOperatorCode('JO')).toBe('11');
    expect(resolvePlansApiOperatorCode('JIO')).toBe('11');
    expect(resolvePlansApiOperatorCode('VI')).toBe('23');
    expect(resolvePlansApiOperatorCode('VODAFONE')).toBe('23');
    expect(resolvePlansApiOperatorCode('IDEA')).toBe('6');
    expect(resolvePlansApiOperatorCode('BT')).toBe('4');
  });

  test('TEST 2 — A1TOPUP OPERATOR RESOLUTION: Canonical codes resolve to A1Topup string provider codes', () => {
    expect(resolveA1TopupOperatorCode({ operatorCode: 'AT' })).toBe('AT');
    expect(resolveA1TopupOperatorCode({ operatorCode: 'JO' })).toBe('JO');
    expect(resolveA1TopupOperatorCode({ operatorCode: 'VI' })).toBe('VI');
    expect(resolveA1TopupOperatorCode({ operatorCode: 'BT' })).toBe('BT');
  });

  test('TEST 3 — RAW PLANSAPI CODES TO A1TOPUP ARE TRANSLATED: A1Topup never receives raw numeric PlansAPI codes', () => {
    // If client passes raw PlansAPI numeric code '2' (Airtel) to recharge
    expect(resolveA1TopupOperatorCode({ providerOperatorCode: '2' })).toBe('AT');

    // If client passes raw PlansAPI numeric code '11' (Jio) to recharge
    expect(resolveA1TopupOperatorCode({ providerOperatorCode: '11' })).toBe('JO');

    // If client passes raw PlansAPI numeric code '23' (Vodafone) to recharge
    expect(resolveA1TopupOperatorCode({ providerOperatorCode: '23' })).toBe('VI');

    // If client passes raw PlansAPI numeric code '4' (BSNL Topup) to recharge
    expect(resolveA1TopupOperatorCode({ providerOperatorCode: '4' })).toBe('BT');

    // If client passes raw PlansAPI numeric code '5' (BSNL Special STV) to recharge
    expect(resolveA1TopupOperatorCode({ providerOperatorCode: '5' })).toBe('BR');
  });

  test('TEST 4 — BSNL SPECIAL STV ROUTING: BSNL STV plans route to BR for A1Topup', () => {
    expect(resolveA1TopupOperatorCode({
      operatorName: 'BSNL',
      operatorCode: 'BT',
      planType: 'STV',
    })).toBe('BR');

    expect(resolveA1TopupOperatorCode({
      operatorName: 'BSNL',
      operatorCode: 'BT',
      selectedCategory: 'DATA VOUCHER',
    })).toBe('BR');
  });

  test('TEST 5 — SERVICE ISOLATION: PlanApiService and A1TopupProvider methods remain isolated', () => {
    expect(typeof planApiService.fetchMobilePlans).toBe('function');
    expect(typeof planApiService.checkLastRecharge).toBe('function');
    expect(planApiService.recharge).toBeUndefined(); // PlanApiService does NOT have recharge method!

    expect(typeof a1TopupProvider.recharge).toBe('function');
    expect(typeof a1TopupProvider.balance).toBe('function');
    expect(a1TopupProvider.fetchMobilePlans).toBeUndefined(); // A1TopupProvider does NOT have fetchMobilePlans!
  });
});
