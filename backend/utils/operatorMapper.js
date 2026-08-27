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
 * NEVER send A1Topup codes to PlansAPI.
 */
function resolvePlansApiOperatorCode(operator) {
  if (typeof operator === 'string') {
    return operator.trim();
  }
  return getPlansApiOperatorCode(operator);
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
