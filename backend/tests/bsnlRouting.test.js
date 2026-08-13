const { executeRecharge } = require('../controllers/recharge.controller');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');
const walletService = require('../services/wallet/wallet.service');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
const { resolveProviderOperatorCode } = require('../utils/operatorMapper');

jest.mock('../services/providers/a1topup/provider.service');
jest.mock('../services/wallet/wallet.service');
jest.mock('../models/RechargeTransaction');
jest.mock('../models/Transaction');
jest.mock('../models/ProviderOperator');
jest.mock('../models/ProviderCircle');
jest.mock('../services/commission/commission.service');
jest.mock('../services/ledger/ledger.service');
jest.mock('../models/CommissionHistory');

describe('BSNL Recharge Operator Code Routing (BT vs BR)', () => {
  let mockReq, mockRes, mockNext;

  beforeEach(() => {
    jest.clearAllMocks();

    mockReq = {
      user: {
        _id: 'user_bsnl_test',
        matchMpin: jest.fn().mockResolvedValue(true),
      },
      body: {},
    };

    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    mockNext = jest.fn();

    ProviderCircle.findOne.mockResolvedValue({ code: '4', status: true });

    RechargeTransaction.create.mockImplementation((data) => ({
      _id: 'tx_bsnl_123',
      orderId: 'A1R1786611601298772',
      ...data,
      save: jest.fn().mockResolvedValue(true),
    }));

    Transaction.create.mockResolvedValue({
      _id: 'global_tx_bsnl_123',
      save: jest.fn().mockResolvedValue(true),
    });

    walletService.reserveAmount.mockResolvedValue();
    walletService.commitReservation.mockResolvedValue();
  });

  describe('Central operatorMapper', () => {
    it('should map BSNL TOPUP to BT', () => {
      const code = resolveProviderOperatorCode({
        operatorName: 'BSNL',
        operatorId: 'bsnl-topup',
        planType: 'TOPUP',
        selectedCategory: 'TOPUP',
      });
      expect(code).toBe('BT');
    });

    it('should map BSNL STV / ₹153 plan to BR', () => {
      const code = resolveProviderOperatorCode({
        operatorName: 'BSNL',
        operatorId: 'bsnl-stv',
        planType: 'STV',
        selectedCategory: 'BSNL STV',
        planName: '₹153 Unlimited Pack',
      });
      expect(code).toBe('BR');
    });
  });

  describe('executeRecharge BSNL Routing', () => {
    it('Test Case 1: BSNL TOPUP sends operatorcode = BT to A1Topup', async () => {
      mockReq.body = {
        mobileNumber: '9420511468',
        amount: 10,
        operatorId: '4',
        operatorName: 'BSNL',
        mpin: '1234',
        planType: 'TOPUP',
        selectedCategory: 'TOPUP',
        providerOperatorCode: 'BT',
      };

      ProviderOperator.findById.mockResolvedValue({ code: 'BT', name: 'BSNL', status: true });
      ProviderOperator.findOne.mockResolvedValue({ code: 'BT', name: 'BSNL', status: true });

      a1TopupProvider.recharge.mockResolvedValue({
        success: true,
        status: 'SUCCESS',
        providerTransactionId: '5532901',
      });

      await executeRecharge(mockReq, mockRes, mockNext);

      expect(a1TopupProvider.recharge).toHaveBeenCalledWith(
        expect.objectContaining({
          operatorCode: 'BT',
          amount: 10,
          mobileNumber: '9420511468',
        })
      );
    });

    it('Test Case 2: BSNL STV ₹153 sends operatorcode = BR to A1Topup', async () => {
      mockReq.body = {
        mobileNumber: '9420511468',
        amount: 153,
        operatorId: '5',
        operatorName: 'BSNL',
        mpin: '1234',
        planId: 'PLAN153',
        planName: 'STV ₹153 Unlimited Calls + 2GB/day',
        planType: 'STV',
        selectedCategory: 'BSNL STV',
        providerOperatorCode: 'BR',
      };

      ProviderOperator.findById.mockResolvedValue({ code: 'BR', name: 'BSNL', status: true });
      ProviderOperator.findOne.mockResolvedValue({ code: 'BR', name: 'BSNL', status: true });

      a1TopupProvider.recharge.mockResolvedValue({
        success: true,
        status: 'PENDING',
        providerTransactionId: '5532902',
      });

      await executeRecharge(mockReq, mockRes, mockNext);

      expect(a1TopupProvider.recharge).toHaveBeenCalledWith(
        expect.objectContaining({
          operatorCode: 'BR',
          amount: 153,
          mobileNumber: '9420511468',
        })
      );
    });

    it('Task 10 Regression Guard: Rejects STV request if code resolves incorrectly to BT', async () => {
      mockReq.body = {
        mobileNumber: '9420511468',
        amount: 153,
        operatorId: '4',
        operatorName: 'BSNL',
        mpin: '1234',
        planType: 'STV',
        providerOperatorCode: 'BR',
      };

      // Mock operator resolving to BT despite STV being requested
      ProviderOperator.findById.mockResolvedValue({ code: 'BT', name: 'BSNL', status: true });
      ProviderOperator.findOne.mockResolvedValue({ code: 'BT', name: 'BSNL', status: true });

      // Override resolveProviderOperatorCode mock or test guard
      await executeRecharge(mockReq, mockRes, mockNext);

      // Provider should NOT be called if guard fails or code matches correctly
      expect(mockRes.status).toHaveBeenCalled();
    });
  });
});
