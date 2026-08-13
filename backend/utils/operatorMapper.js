/**
 * Centralized Provider Operator Code Mapper
 * 
 * Rules for BSNL:
 * - BSNL TOPUP => BT
 * - BSNL STV / Special Tariff Voucher / Combo / Data / Rate Cutter => BR
 */

function isBsnlOperator(operatorName = '', operatorId = '', operatorCode = '') {
  const nameStr = String(operatorName || '').toUpperCase();
  const idStr = String(operatorId || '').toUpperCase();
  const codeStr = String(operatorCode || '').toUpperCase();

  return nameStr.includes('BSNL') || 
         idStr.includes('BSNL') || 
         idStr === '4' || 
         idStr === '5' || 
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

  // Keywords indicating STV / Special plan
  const stvKeywords = ['STV', 'SPECIAL', 'COMBO', 'DATA', 'VOUCHER', 'RATE CUTTER', '3G/4G', 'RECOMMENDED', 'PLAN'];
  for (const kw of stvKeywords) {
    if (cat.includes(kw) || name.includes(kw)) {
      // Exception: Topup / Full TT category or name
      if (cat.includes('TOPUP') || cat.includes('FULLTT') || cat.includes('TALKTIME')) {
        return false;
      }
      return true;
    }
  }

  return false;
}

function resolveProviderOperatorCode(params = {}) {
  const {
    operator,
    operatorId = '',
    operatorName = '',
    planType = '',
    selectedCategory = '',
    planName = '',
    providerOperatorCode: reqProviderOpCode = '',
  } = params;

  const opName = operator?.name || operatorName;
  const opCode = operator?.code || '';

  // Check if BSNL operator
  if (isBsnlOperator(opName, operatorId, opCode)) {
    if (isBsnlStvPlan(planType, selectedCategory, planName, reqProviderOpCode, operatorId)) {
      return 'BR';
    }
    return 'BT';
  }

  // Explicit provider code passed from client / operator model
  if (reqProviderOpCode && reqProviderOpCode.trim() !== '') {
    return reqProviderOpCode.trim().toUpperCase();
  }

  if (operator && operator.code) {
    return operator.code.trim().toUpperCase();
  }

  return 'UNKNOWN';
}

module.exports = {
  isBsnlOperator,
  isBsnlStvPlan,
  resolveProviderOperatorCode,
};
