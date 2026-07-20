const { executeRecharge } = require('../controllers/recharge.controller');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');
const walletService = require('../services/wallet/wallet.service');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
const commissionService = require('../services/commission/commission.service');
const ledgerService = require('../services/ledger/ledger.service');

jest.mock('../services/providers/a1topup/provider.service');
jest.mock('../services/wallet/wallet.service');
jest.mock('../models/RechargeTransaction');
jest.mock('../models/Transaction');
jest.mock('../models/ProviderOperator');
jest.mock('../models/ProviderCircle');
jest.mock('../services/commission/commission.service');
jest.mock('../services/ledger/ledger.service');
jest.mock('../models/CommissionHistory');

describe('Recharge Controller - executeRecharge', () => {
  let mockReq, mockRes, mockNext;

  beforeEach(() => {
    jest.clearAllMocks();

    mockReq = {
      user: {
        _id: 'user_123',
        matchMpin: jest.fn().mockResolvedValue(true),
      },
      body: {
        mobileNumber: '9999999999',
        amount: 100,
        operatorId: 'RC',
        mpin: '1234',
        paymentMode: 'wallet',
      },
    };

    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    mockNext = jest.fn();

    ProviderOperator.findOne.mockResolvedValue({ code: 'RC', name: 'Jio', status: true });
    ProviderCircle.findOne.mockResolvedValue({ code: '4', status: true });
    
    RechargeTransaction.create.mockResolvedValue({
      _id: 'tx_123',
      orderId: 'A1R123',
      save: jest.fn(),
    });
    
    Transaction.create.mockResolvedValue({
      _id: 'global_tx_123',
      save: jest.fn(),
    });
    Transaction.updateOne = jest.fn().mockResolvedValue({});
    RechargeTransaction.updateOne = jest.fn().mockResolvedValue({});
    
    walletService.reserveAmount.mockResolvedValue();
    walletService.commitReservation.mockResolvedValue();
    walletService.releaseReservation.mockResolvedValue();
    
    commissionService.calculateCommission.mockResolvedValue({
      retailerCommissionAmount: 5,
      providerCommissionAmount: 10,
    });
    
    const CommissionHistory = require('../models/CommissionHistory');
    CommissionHistory.findOne = jest.fn().mockResolvedValue({ retailerCommissionAmount: 5 });
    CommissionHistory.create = jest.fn().mockResolvedValue({});
  });

  it('should handle SUCCESS status correctly', async () => {
    a1TopupProvider.recharge.mockResolvedValue({
      success: true,
      status: 'SUCCESS',
      providerTransactionId: 'pt_123',
    });

    await executeRecharge(mockReq, mockRes, mockNext);

    expect(walletService.reserveAmount).toHaveBeenCalled();
    expect(walletService.commitReservation).toHaveBeenCalled();
    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(mockRes.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Recharge successful',
      data: expect.objectContaining({ status: 'success' })
    }));
    
    // Check if Transaction.create was called twice (once for recharge, once for commission)
    expect(Transaction.create).toHaveBeenCalledTimes(2);
    expect(Transaction.create).toHaveBeenNthCalledWith(1, expect.objectContaining({
      service: 'mobile_recharge',
      type: 'debit',
    }));
    expect(Transaction.create).toHaveBeenNthCalledWith(2, expect.objectContaining({
      service: 'commission',
      type: 'credit',
      amountPaise: 500, // 5 * 100
    }));
  });

  it('should handle FAILED status correctly', async () => {
    a1TopupProvider.recharge.mockResolvedValue({
      success: false,
      status: 'FAILED',
      message: 'Insufficient balance at provider',
    });

    await executeRecharge(mockReq, mockRes, mockNext);

    expect(walletService.reserveAmount).toHaveBeenCalled();
    expect(walletService.releaseReservation).toHaveBeenCalled();
    expect(mockRes.status).toHaveBeenCalledWith(400);
    expect(mockRes.json).toHaveBeenCalledWith(expect.objectContaining({
      success: false,
      message: 'Insufficient balance at provider'
    }));
  });

  it('should handle PENDING status correctly', async () => {
    a1TopupProvider.recharge.mockResolvedValue({
      success: false,
      status: 'PENDING',
      message: 'Pending verification',
    });

    await executeRecharge(mockReq, mockRes, mockNext);

    expect(walletService.reserveAmount).toHaveBeenCalled();
    expect(walletService.commitReservation).not.toHaveBeenCalled(); // Should keep reservation
    expect(walletService.releaseReservation).not.toHaveBeenCalled();
    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(mockRes.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Recharge pending verification',
      data: expect.objectContaining({ status: 'pending' })
    }));
  });

  it('should handle TIMEOUT correctly (caught as error then processed)', async () => {
    a1TopupProvider.recharge.mockRejectedValue(new Error('timeout of 10000ms exceeded'));

    await executeRecharge(mockReq, mockRes, mockNext);

    // If it throws an error in recharge(), executeRecharge's catch block runs
    expect(walletService.reserveAmount).toHaveBeenCalled();
    expect(walletService.releaseReservation).toHaveBeenCalled(); // Released in catch block
    expect(mockNext).toHaveBeenCalled();
  });
});
