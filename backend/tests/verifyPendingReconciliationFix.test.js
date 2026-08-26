const { normalizeStatus, logStatusCheckAudit } = require('../utils/statusNormalizer');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const pendingRechargeWorker = require('../workers/pendingRecharge.worker');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');

describe('Recharge Status Reconciliation & State Machine Test Suite', () => {

  test('Status Normalizer maps statuses correctly', () => {
    expect(normalizeStatus('SUCCESS')).toEqual({ canonical: 'SUCCESS', global: 'success', isTerminal: true });
    expect(normalizeStatus('COMPLETED')).toEqual({ canonical: 'SUCCESS', global: 'success', isTerminal: true });
    expect(normalizeStatus('FAILED')).toEqual({ canonical: 'FAILED', global: 'failed', isTerminal: true });
    expect(normalizeStatus('FAILURE')).toEqual({ canonical: 'FAILED', global: 'failed', isTerminal: true });
    expect(normalizeStatus('ERROR')).toEqual({ canonical: 'FAILED', global: 'failed', isTerminal: true });
    expect(normalizeStatus('PENDING')).toEqual({ canonical: 'PROCESSING', global: 'processing', isTerminal: false });
    expect(normalizeStatus('PROCESSING')).toEqual({ canonical: 'PROCESSING', global: 'processing', isTerminal: false });
    expect(normalizeStatus('IN_PROGRESS')).toEqual({ canonical: 'PROCESSING', global: 'processing', isTerminal: false });
  });

  test('Status check audit logging function executes cleanly without throwing', () => {
    expect(() => {
      logStatusCheckAudit({
        internalTransactionId: 'AIR1234567890',
        providerTransactionId: 'PROV123',
        orderId: 'AIR1234567890',
        providerStatus: 'PENDING',
        normalizedStatus: normalizeStatus('PENDING'),
      });
    }).not.toThrow();
  });
});
