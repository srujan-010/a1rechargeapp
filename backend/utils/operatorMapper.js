/**
 * Centralized Provider Operator Mapper & Resolver
 * 
 * Enforces strict isolation between PlansAPI operator codes and A1Topup operator codes.
 * Codes are NEVER translated, guessed, or cross-mapped between providers.
 */

const { getA1TopupOperatorCode, getPlansApiOperatorCode } = require('./operatorResolver');

function isBsnlOperator(operatorName = '', operatorId = '', operatorCode = '') {
  const nameStr = String(operatorName || '').toUpperCase();
  const idStr = String(operatorId || '').toUpperCase();
  const codeStr = String(operatorCode || '').toUpperCase();

  return nameStr.includes('BSNL') || 
         idStr.includes('BSNL') || 
         idStr === 'BT' || 
         idStr === 'BR' || 
         codeStr === 'BT' || 
         codeStr === 'BR';
}

function isBsnlStvPlan(planType = '', selectedCategory = '', planName = '', reqProviderOpCode = '', operatorId = '') {
  const pType = String(planType || '').toUpperCase().trim();
  const cat = String(selectedCategory || '').toUpperCase().trim();
  const name = String(planName || '').toUpperCase().trim();
  const reqCode = String(reqProviderOpCode || '').toUpperCase().trim();
  const id = String(operatorId || '').toLowerCase().trim();

  if (reqCode === 'BR' || id === '5' || id === 'bsnl-stv' || id === 'bsnl_stv' || id === 'bsnl special' || id === 'bsnl-special') {
    return true;
  }
  if (pType === 'STV' || pType === 'SPECIAL' || pType === 'BSNL STV') {
    return true;
  }

  const stvKeywords = ['STV', 'SPECIAL', 'COMBO', 'DATA', 'VOUCHER', 'RATE CUTTER', '3G/4G', 'RECOMMENDED', 'PLAN'];
  for (const kw of stvKeywords) {
    if (cat.includes(kw) || name.includes(kw)) {
      if (cat.includes('TOPUP') || cat.includes('FULLTT') || cat.includes('TALKTIME')) {
        return false;
      }
      return true;
    }
  }

  return false;
}

/**
 * Resolve PlansAPI specific operator code.
 * NEVER send A1Topup codes (like BT/BR) to PlansAPI.
 * NEVER send PlansAPI numeric codes to A1Topup.
 * 
 * PlansAPI BSNL Codes:
 * - BSNL TOPUP: 4
 * - BSNL SPECIAL / STV: 5
 */
function resolvePlansApiOperatorCode(operator, planType = '') {
  const pType = String(planType || '').toUpperCase().trim();

  if (typeof operator === 'string') {
    const clean = operator.trim();
    const upper = clean.toUpperCase();

    // Direct PlansAPI numeric codes
    if (clean === '4') return '4';
    if (clean === '5') return '5';
    if (clean === '2') return '2';
    if (clean === '23') return '23';
    if (clean === '11') return '11';

    // BSNL PlansAPI Operator Codes
    if (upper === 'BT' || upper === 'BSNL TOPUP' || upper === 'BSNL-TOPUP' || upper === 'BSNL_TOPUP') {
      return '4';
    }
    if (upper === 'BR' || upper === 'BSNL SPECIAL' || upper === 'BSNL-STV' || upper === 'BSNL_STV' || upper === 'BSNL STV') {
      return '5';
    }

    if (upper === 'BSNL' || upper === 'BSNL GSM') {
      if (pType === 'SPECIAL' || pType === 'STV' || pType === 'BSNL SPECIAL' || pType === 'BSNL STV') {
        return '5';
      }
      return '4'; // BSNL TOPUP default
    }

    if (upper === 'AT' || upper === 'AIRTEL' || upper === 'A') return '2';
    if (upper === 'VI' || upper === 'VODAFONE' || upper === 'V' || upper === 'IDEA' || upper === 'I') return '23';
    if (upper === 'JIO' || upper === 'RELIANCE' || upper === 'RC' || upper === 'RJ') return '11';

    return clean;
  }

  if (operator && typeof operator === 'object') {
    const opName = String(operator.name || operator.operatorName || '').toUpperCase();
    const opCode = String(operator.code || operator.a1TopupCode || operator.operatorCode || '').toUpperCase();

    if (opName.includes('BSNL') || opCode === 'BT' || opCode === 'BR' || opCode === 'BSNL') {
      if (pType === 'SPECIAL' || pType === 'STV' || opCode === 'BR' || opName.includes('SPECIAL') || opName.includes('STV')) {
        return '5';
      }
      return '4';
    }

    if (opName.includes('AIRTEL') || opCode === 'A' || opCode === 'AT') return '2';
    if (opName.includes('VODAFONE') || opName.includes('VI') || opName.includes('IDEA') || opCode === 'V' || opCode === 'VI' || opCode === 'I') return '23';
    if (opName.includes('JIO') || opName.includes('RELIANCE') || opCode === 'RC' || opCode === 'RJ') return '11';

    if (operator.plansApiCode || operator.plansInfoCode) {
      return String(operator.plansApiCode || operator.plansInfoCode).trim();
    }
  }

  try {
    return getPlansApiOperatorCode(operator);
  } catch (err) {
    return String(operator?.code || operator?.name || operator || '').trim();
  }
}

/**
 * Resolve A1Topup specific operator code.
 * NEVER send PlansAPI codes to A1Topup.
 */
function resolveA1TopupOperatorCode(params = {}) {
  const {
    operator,
    planType = '',
    selectedCategory = '',
    planName = '',
    providerOperatorCode: reqProviderOpCode = '',
    operatorId = '',
  } = params;

  if (operator) {
    const code = getA1TopupOperatorCode(operator);
    const opName = operator.name || '';
    if (isBsnlOperator(opName, operatorId, code)) {
      if (isBsnlStvPlan(planType, selectedCategory, planName, reqProviderOpCode, operatorId)) {
        return 'BR';
      }
      return 'BT';
    }
    return code;
  }

  const rawCode = String(reqProviderOpCode || '').trim();
  if (!rawCode) {
    throw new Error('MISSING_A1TOPUP_CODE: No valid A1Topup operator code specified.');
  }
  return rawCode;
}

function resolveProviderOperatorCode(params = {}) {
  return resolveA1TopupOperatorCode(params);
}

module.exports = {
  isBsnlOperator,
  isBsnlStvPlan,
  resolvePlansApiOperatorCode,
  resolveA1TopupOperatorCode,
  resolveProviderOperatorCode,
  getA1TopupOperatorCode,
  getPlansApiOperatorCode,
};
