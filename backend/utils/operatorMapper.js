/**
 * Centralized Three-Layer Provider Operator Mapper
 * 
 * Isolates PlansAPI numeric codes from A1Topup string provider codes:
 * Layer 1: Canonical Operator Code (AT, BT, BR, JO, VI, DT, DA, DD, DS, DV)
 * Layer 2: PlansAPI Operator Code (2, 4, 5, 6, 11, 23, etc.)
 * Layer 3: A1Topup Provider Code (AT, BT, BR, JO, VI, DT, etc.)
 */

const PLANSAPI_TO_CANONICAL = {
  '2': 'AT',          // Airtel
  '4': 'BT',          // BSNL Topup
  '5': 'BR',          // BSNL Special / STV
  '6': 'VI',          // Idea
  '11': 'JO',         // Reliance Jio
  '23': 'VI',         // Vodafone
  '12': 'DT',         // Tata Play DTH
  '13': 'DA',         // Airtel DTH
  '14': 'DD',         // Dish TV
  '15': 'DS',         // Sun Direct
  '16': 'DV',         // Videocon d2h
};

const CANONICAL_TO_PLANSAPI = {
  'AT': '2',
  'AIRTEL': '2',
  'BT': '4',
  'BSNL': '4',
  'BR': '5',
  'JO': '11',
  'JIO': '11',
  'VI': '23',
  'VF': '23',
  'VODAFONE': '23',
  'IDEA': '6',
  'DT': '12',
  'DA': '13',
  'DD': '14',
  'DS': '15',
  'DV': '16',
};

const CANONICAL_TO_A1TOPUP = {
  'AT': 'AT',
  'AIRTEL': 'AT',
  'BT': 'BT',
  'BSNL': 'BT',
  'BR': 'BR',
  'JO': 'JO',
  'JIO': 'JO',
  'VI': 'VI',
  'VODAFONE': 'VI',
  'IDEA': 'VI',
  'DT': 'DT',
  'DA': 'DA',
  'DD': 'DD',
  'DS': 'DS',
  'DV': 'DV',
};

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
function resolvePlansApiOperatorCode(operatorCode = '') {
  const op = String(operatorCode || '').trim().toUpperCase();
  if (PLANSAPI_TO_CANONICAL[op]) {
    return op; // Already a PlansAPI numeric code
  }
  return CANONICAL_TO_PLANSAPI[op] || op;
}

/**
 * Resolve A1Topup specific operator code.
 * NEVER send PlansAPI numeric codes (2, 11, 23, 4, 5, 6) directly to A1Topup.
 */
function resolveA1TopupOperatorCode(params = {}) {
  const {
    operator,
    operatorId = '',
    operatorName = '',
    operatorCode = '',
    planType = '',
    selectedCategory = '',
    planName = '',
    providerOperatorCode: reqProviderOpCode = '',
  } = params;

  let rawCode = String(reqProviderOpCode || operatorCode || operator?.code || operatorId || '').trim().toUpperCase();

  // If rawCode is a PlansAPI numeric code, translate it to Canonical first!
  if (PLANSAPI_TO_CANONICAL[rawCode]) {
    rawCode = PLANSAPI_TO_CANONICAL[rawCode];
  }

  // If already mapped to BR (BSNL Special STV from PlansAPI code 5), return BR directly
  if (rawCode === 'BR') {
    return 'BR';
  }

  const opName = operator?.name || operatorName;

  // Special BSNL handling
  if (isBsnlOperator(opName, operatorId, rawCode)) {
    if (isBsnlStvPlan(planType, selectedCategory, planName, reqProviderOpCode, operatorId)) {
      return 'BR';
    }
    return 'BT';
  }

  if (CANONICAL_TO_A1TOPUP[rawCode]) {
    return CANONICAL_TO_A1TOPUP[rawCode];
  }

  return rawCode || 'UNKNOWN';
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
  PLANSAPI_TO_CANONICAL,
  CANONICAL_TO_PLANSAPI,
  CANONICAL_TO_A1TOPUP,
};
