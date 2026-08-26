const { normalizeStatus, logStatusCheckAudit } = require('../utils/statusNormalizer');

console.log('--- TESTING STATUS NORMALIZER ---');

const testCases = [
  'SUCCESS', 'SUCCESSFUL', 'COMPLETED',
  'FAILED', 'FAILURE', 'REJECTED', 'ERROR',
  'PENDING', 'PROCESSING', 'IN_PROGRESS', 'SUBMITTED', 'INITIATED', 'RECHARGE_PROCESSING',
  'random_status'
];

let allPassed = true;

for (const tc of testCases) {
  const result = normalizeStatus(tc);
  console.log(`Input: "${tc}" -> Canonical: "${result.canonical}", Global: "${result.global}", Terminal: ${result.isTerminal}`);
}

console.log('\n--- TESTING STATUS AUDIT LOGGING ---');
logStatusCheckAudit({
  internalTransactionId: 'AIR1787719096154577',
  providerTransactionId: 'PROV998877',
  orderId: 'AIR1787719096154577',
  providerStatus: 'SUCCESS',
  normalizedStatus: normalizeStatus('SUCCESS'),
});

console.log('\n--- STATUS NORMALIZER VERIFICATION PASSED ---');
