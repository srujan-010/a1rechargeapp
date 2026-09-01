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
 * NEVER send A1Topup codes (like BT/BR/ATV/STV) to PlansAPI.
 * NEVER send PlansAPI numeric codes to A1Topup.
 * 
 * PlansAPI DTH Codes:
 * - AIRTEL DTH: 24
 * - DISH TV: 25
 * - RELIANCE BIGTV: 26
 * - SUN DIRECT: 27
 * - TATA SKY / TATA PLAY: 28
 * - VIDEOCON D2H: 29
 * 
 * PlansAPI Mobile Codes:
 * - AIRTEL: 2
 * - VODAFONE / VI: 23
 * - RELIANCE JIO: 11
 * - BSNL TOPUP: 4
 * - BSNL SPECIAL / STV: 5
 */
function resolvePlansApiOperatorCode(operator, planType = '') {
  const pType = String(planType || '').toUpperCase().trim();

  if (typeof operator === 'string') {
    const clean = operator.trim();
    const upper = clean.toUpperCase();

    // Direct PlansAPI numeric codes
    if (['2', '4', '5', '11', '23', '24', '25', '26', '27', '28', '29'].includes(clean)) {
      return clean;
    }

    // DTH Direct Codes & Names
    if (upper === 'ATV' || upper === 'AIRTEL DTH' || upper === 'AIRTEL_DTH' || upper === 'AIRTEL DIGITAL TV') return '24';
    if (upper === 'DTV' || upper === 'DISH TV' || upper === 'DISH_TV' || upper === 'DISH') return '25';
    if (upper === 'RBTV' || upper === 'RELIANCE BIGTV' || upper === 'RELIANCE BIG TV' || upper === 'RELIANCE_BIGTV') return '26';
    if (upper === 'STV' || upper === 'SUN DIRECT' || upper === 'SUN_DIRECT' || upper === 'SUN TV') return '27';
    if (upper === 'TTV' || upper === 'TATA SKY' || upper === 'TATA_SKY' || upper === 'TATA PLAY' || upper === 'TATA_PLAY') return '28';
    if (upper === 'VTV' || upper === 'VIDEOCON D2H' || upper === 'VIDEOCON_D2H' || upper === 'VIDEOCON' || upper === 'D2H') return '29';

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

    // Mobile Direct Codes & Names
    if (upper === 'AT' || upper === 'AIRTEL' || upper === 'A' || upper.includes('AIRTEL') || upper.includes('BHARTI AIRTEL')) return '2';
    if (upper === 'VI' || upper === 'VODAFONE' || upper === 'V' || upper === 'IDEA' || upper === 'I' || upper.includes('VODAFONE') || upper.includes('IDEA') || upper.includes('VI')) return '23';
    if (upper === 'JIO' || upper === 'RELIANCE' || upper === 'RC' || upper === 'RJ' || upper.includes('JIO') || upper.includes('RELIANCE JIO') || upper.includes('RELIANCE')) return '11';

    return clean;
  }

  if (operator && typeof operator === 'object') {
    const opName = String(operator.name || operator.operatorName || '').toUpperCase();
    const opCode = String(operator.code || operator.a1TopupCode || operator.operatorCode || '').toUpperCase();
    const sType = String(operator.serviceType || operator.service || '').toUpperCase();

    if (operator.plansApiCode && String(operator.plansApiCode).trim().length > 0) {
      return String(operator.plansApiCode).trim();
    }

    // DTH Checks
    if (sType === 'DTH' || opName.includes('DTH') || opName.includes('TV') || opName.includes('SKY') || opName.includes('SUN') || opName.includes('VIDEOCON') || ['ATV', 'DTV', 'RBTV', 'STV', 'TTV', 'VTV'].includes(opCode)) {
      if (opCode === 'ATV' || opName.includes('AIRTEL')) return '24';
      if (opCode === 'DTV' || opName.includes('DISH')) return '25';
      if (opCode === 'RBTV' || opName.includes('RELIANCE')) return '26';
      if (opCode === 'STV' || opName.includes('SUN')) return '27';
      if (opCode === 'TTV' || opName.includes('TATA')) return '28';
      if (opCode === 'VTV' || opName.includes('VIDEOCON') || opName.includes('D2H')) return '29';
    }

    // BSNL Checks
    if (opName.includes('BSNL') || opCode === 'BT' || opCode === 'BR') {
      if (pType === 'SPECIAL' || pType === 'STV' || opCode === 'BR' || opName.includes('SPECIAL') || opName.includes('STV')) {
        return '5';
      }
      return '4';
    }

    // Mobile Checks
    if (opCode === 'A' || opCode === 'AT' || (opName.includes('AIRTEL') && sType !== 'DTH')) return '2';
    if (opName.includes('VODAFONE') || opName.includes('VI') || opName.includes('IDEA') || opCode === 'V' || opCode === 'VI' || opCode === 'I') return '23';
    if (opName.includes('JIO') || (opName.includes('RELIANCE') && sType !== 'DTH') || opCode === 'RC' || opCode === 'RJ') return '11';

    if (operator.plansInfoCode && String(operator.plansInfoCode).trim().length > 0) {
      return String(operator.plansInfoCode).trim();
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
    operatorName = '',
    planType = '',
    selectedCategory = '',
    planName = '',
    providerOperatorCode: reqProviderOpCode = '',
    operatorId = '',
  } = params;

  const opName = operator?.name || operatorName || '';
  const rawCode = operator ? (operator.a1TopupCode || operator.code || reqProviderOpCode) : reqProviderOpCode;

  if (isBsnlOperator(opName, operatorId, rawCode)) {
    if (isBsnlStvPlan(planType, selectedCategory, planName, reqProviderOpCode, operatorId)) {
      return 'BR';
    }
    return 'BT';
  }

  if (operator) {
    return getA1TopupOperatorCode(operator);
  }

  const cleanCode = String(rawCode || '').trim();
  if (!cleanCode) {
    throw new Error('MISSING_A1TOPUP_CODE: No valid A1Topup operator code specified.');
  }
  return cleanCode;
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

