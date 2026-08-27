/**
 * Strict Provider Operator Resolver Module
 * 
 * Enforces absolute separation between A1Topup operator codes and PlansAPI operator codes.
 * Codes are NEVER translated, inferred, or used interchangeably between providers.
 */

/**
 * Resolves A1Topup operator code for recharge execution.
 * @param {Object} operator - Database ProviderOperator document or operator object
 * @returns {string} The explicit A1Topup operator code (e.g., 'A', 'V', 'BT', 'RC', 'I', 'BR')
 */
function getA1TopupOperatorCode(operator) {
  if (!operator) {
    throw new Error('INVALID_OPERATOR: Operator document is null or undefined.');
  }

  const code = String(operator.a1TopupCode || (operator.provider === 'A1Topup' ? operator.code : null) || operator.code || '').trim();

  if (!code) {
    throw new Error(`MISSING_A1TOPUP_CODE: No A1Topup operator code configured for operator '${operator.name || 'Unknown'}'.`);
  }

  return code;
}

/**
 * Resolves PlansAPI operator code for plan fetching & customer info.
 * @param {Object} operator - Database ProviderOperator document or operator object
 * @returns {string} The explicit PlansAPI operator code (e.g., 'AT', 'VI', 'CG', 'RJ', 'ID', '2', '23', etc.)
 */
function getPlansApiOperatorCode(operator) {
  if (!operator) {
    throw new Error('INVALID_OPERATOR: Operator document is null or undefined.');
  }

  const code = String(operator.plansApiCode || operator.plansInfoCode || '').trim();

  if (!code) {
    throw new Error(`MISSING_PLANS_API_CODE: No PlansAPI operator code configured for operator '${operator.name || 'Unknown'}'.`);
  }

  return code;
}

module.exports = {
  getA1TopupOperatorCode,
  getPlansApiOperatorCode,
};
