/**
 * Centralized DTH Operator Mapping Service
 * Maps PlansInfo DTH operator codes to A1 Topup DTH operator codes.
 * 
 * Mapping Rules:
 * PlansInfo → A1 Topup
 * AD  → ATV   (Airtel Digital TV)
 * SD  → STV   (Sun Direct)
 * TS  → TTV   (Tata Play)
 * VD  → VTV   (Videocon d2h)
 * DT  → DTV   (Dish TV)
 */

const DTH_PLANINFO_TO_A1_MAP = Object.freeze({
  '24': 'ATV',
  '25': 'DTV',
  '26': 'RBTV',
  '27': 'STV',
  '28': 'TTV',
  '29': 'VTV',
});

// A1 Topup native codes for direct validation
const A1_DTH_CODES = new Set(['ATV', 'STV', 'TTV', 'VTV', 'DTV', 'RBTV']);

/**
 * Converts a PlansInfo DTH operator code (or ProviderOperator object) into the corresponding A1 Topup code.
 * @param {string|object} input - PlansInfo code string or ProviderOperator Mongoose object
 * @returns {string} - Mapped A1 Topup operator code
 * @throws {Error} - If operator code is unmapped or missing
 */
function getA1DthOperatorCode(input) {
  console.log("ENTERED:", __filename, "FUNCTION: getA1DthOperatorCode");
  let plansInfoCode = '';

  if (typeof input === 'string') {
    plansInfoCode = input.trim().toUpperCase();
  } else if (input && typeof input === 'object') {
    plansInfoCode = (input.plansInfoCode || input.code || '').trim().toUpperCase();
  }

  if (!plansInfoCode) {
    throw new Error('DTH Operator Mapping Error: Missing or invalid operator code');
  }

  // If already an A1 Topup code, return directly
  if (A1_DTH_CODES.has(plansInfoCode)) {
    console.log(`PlansInfo Operator: ${plansInfoCode}`);
    console.log(`Mapped A1 Operator: ${plansInfoCode}`);
    return plansInfoCode;
  }

  const mappedA1Code = DTH_PLANINFO_TO_A1_MAP[plansInfoCode];

  console.log(`PlansInfo Operator: ${plansInfoCode}`);
  console.log(`Mapped A1 Operator: ${mappedA1Code || 'UNMAPPED_ERROR'}`);

  if (!mappedA1Code) {
    throw new Error(`DTH Operator Mapping Error: Unsupported or unmapped PlansInfo DTH operator code '${plansInfoCode}'`);
  }

  return mappedA1Code;
}

module.exports = {
  DTH_PLANINFO_TO_A1_MAP,
  getA1DthOperatorCode,
};
