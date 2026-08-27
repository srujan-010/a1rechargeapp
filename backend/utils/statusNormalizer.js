/**
 * Centralized Status Normalizer for Recharge Provider & Internal Transaction Lifecycles
 */

/**
 * Normalizes raw provider status strings into canonical database and API statuses.
 * @param {string} rawStatus 
 * @returns {{ canonical: 'SUCCESS'|'FAILED'|'PROCESSING', global: 'success'|'failed'|'processing', isTerminal: boolean }}
 */
const normalizeStatus = (rawStatus) => {
  const str = String(rawStatus || '').toUpperCase().trim();

  if (['SUCCESS', 'SUCCESSFUL', 'COMPLETED'].includes(str)) {
    return {
      canonical: 'SUCCESS',
      global: 'success',
      isTerminal: true,
    };
  }

  if (['FAILED', 'FAILURE', 'REJECTED', 'ERROR'].includes(str)) {
    return {
      canonical: 'FAILED',
      global: 'failed',
      isTerminal: true,
    };
  }

  if (['PENDING', 'PROCESSING', 'IN_PROGRESS', 'SUBMITTED', 'INITIATED', 'RECHARGE_PROCESSING', 'ACCEPTED', 'QUEUED'].includes(str)) {
    return {
      canonical: 'PROCESSING',
      global: 'processing',
      isTerminal: false,
    };
  }

  // Unknown or missing statuses (e.g. UNKNOWN, empty, null, error responses)
  return {
    canonical: 'UNKNOWN',
    global: 'unknown',
    isTerminal: false,
  };
};

/**
 * Audit log helper for recording provider status check responses.
 */
const logStatusCheckAudit = ({ internalTransactionId, providerTransactionId, orderId, providerStatus, normalizedStatus, checkedAt = new Date() }) => {
  const safeProviderTxId = (!providerTransactionId || providerTransactionId === 'N/A') ? null : providerTransactionId;
  console.log(`[STATUS AUDIT LOG ${checkedAt.toISOString()}]`, {
    internalTransactionId: internalTransactionId || null,
    providerTransactionId: safeProviderTxId || 'N/A',
    orderId: orderId || null,
    providerStatus: providerStatus || 'UNKNOWN',
    normalizedStatus: normalizedStatus ? normalizedStatus.canonical : 'UNKNOWN',
    isTerminal: normalizedStatus ? normalizedStatus.isTerminal : false,
  });
};

module.exports = {
  normalizeStatus,
  logStatusCheckAudit,
};
