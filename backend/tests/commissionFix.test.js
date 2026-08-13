const OperatorCommission = require('../models/OperatorCommission');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const CommissionHistory = require('../models/CommissionHistory');
const walletService = require('../services/wallet/wallet.service');
const commissionService = require('../services/commission/commission.service');
const ledgerService = require('../services/ledger/ledger.service');
const { executeRecharge } = require('../controllers/recharge.controller');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');

jest.mock('../models/OperatorCommission');
jest.mock('../models/RechargeTransaction');
jest.mock('../models/Transaction');
jest.mock('../models/CommissionHistory');
jest.mock('../models/ProviderOperator');
jest.mock('../models/ProviderCircle');
jest.mock('../services/providers/a1topup/provider.service');
jest.mock('../services/wallet/wallet.service');
jest.mock('../services/ledger/ledger.service');
jest.mock('../services/fast2sms.service', () => ({
  sendRechargeSuccessTemplate: jest.fn().mockResolvedValue({ success: true }),
}));
jest.mock('../services/notification.service', () => ({
  sendRechargeSuccess: jest.fn(),
  sendRechargeFailed: jest.fn(),
  sendRechargePending: jest.fn(),
}));

describe('Recharge Commission System Verification', () => {
  let mockReq, mockRes, mockNext;

  beforeEach(() => {
    jest.clearAllMocks();

    mockReq = {
      user: {
        _id: 'retailer_123',
        matchMpin: jest.fn().mockResolvedValue(true),
        name: 'Test Retailer',
      },
      body: {},
    };

    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    mockNext = jest.fn();

    walletService.reserveAmount.mockResolvedValue(true);
    walletService.commitReservation.mockResolvedValue(true);
    walletService.addBalance.mockResolvedValue(true);
    walletService.getWalletBalance.mockResolvedValue(1000.00);

    ledgerService.logTransaction.mockResolvedValue({ _id: 'ledger_entry_999' });

    RechargeTransaction.create.mockImplementation(async (data) => ({
      ...data,
      _id: 'txn_recharge_id_123',
      save: jest.fn().mockResolvedValue(true),
    }));

    Transaction.create.mockImplementation(async (data) => ({
      ...data,
      _id: 'global_txn_id_123',
      save: jest.fn().mockResolvedValue(true),
    }));

    CommissionHistory.create.mockImplementation(async (data) => ({
      ...data,
      _id: 'comm_hist_id_123',
    }));
    CommissionHistory.findOne.mockReturnValue({
      catch: jest.fn().mockImplementation((cb) => cb(null)),
      then: jest.fn().mockImplementation((cb) => cb(null)),
    });

    const ProviderOperator = require('../models/ProviderOperator');
    const ProviderCircle = require('../models/ProviderCircle');

    const opObj = { _id: 'op_4', name: 'Airtel', code: 'AT', serviceType: 'mobile', status: 'ACTIVE' };
    ProviderOperator.findById.mockResolvedValue(opObj);
    ProviderOperator.findOne.mockImplementation(() => {
      const p = Promise.resolve(opObj);
      p.lean = jest.fn().mockResolvedValue(opObj);
      return p;
    });

    ProviderCircle.findOne.mockReturnValue({
      lean: jest.fn().mockResolvedValue({ _id: 'circle_4', circleCode: '4', circleName: 'Maharashtra' }),
    });
  });

  it('Step 10: Verify operator commission lookup for Airtel, BSNL Topup, BSNL STV, and Jio without NaN', async () => {
    OperatorCommission.findOne.mockImplementation(({ operatorCode, $or }) => {
      let codeMatch = null;

      if (operatorCode === 'BR') {
        codeMatch = { _id: 'comm_br', operatorCode: 'BR', operatorName: 'BSNL STV', serviceType: 'mobile', providerCommission: 4.5, retailerCommission: 2.8, companyCommission: 1.7, status: 'ACTIVE' };
      } else if (operatorCode === 'BT') {
        codeMatch = { _id: 'comm_bt', operatorCode: 'BT', operatorName: 'BSNL TOPUP', serviceType: 'mobile', providerCommission: 5.0, retailerCommission: 3.0, companyCommission: 2.0, status: 'ACTIVE' };
      } else if (operatorCode === 'AT' || operatorCode === 'A') {
        codeMatch = { _id: 'comm_at', operatorCode: 'AT', operatorName: 'Airtel', serviceType: 'mobile', providerCommission: 4.0, retailerCommission: 2.5, companyCommission: 1.5, status: 'ACTIVE' };
      } else if (operatorCode === 'JO' || operatorCode === 'RC') {
        codeMatch = { _id: 'comm_jo', operatorCode: 'JO', operatorName: 'Jio', serviceType: 'mobile', providerCommission: 3.5, retailerCommission: 2.0, companyCommission: 1.5, status: 'ACTIVE' };
      } else if ($or && Array.isArray($or)) {
        const inClause = $or.find((item) => item.operatorCode && item.operatorCode.$in);
        if (inClause) {
          const arr = inClause.operatorCode.$in;
          if (arr.includes('BR')) {
            codeMatch = { _id: 'comm_br', operatorCode: 'BR', operatorName: 'BSNL STV', serviceType: 'mobile', providerCommission: 4.5, retailerCommission: 2.8, companyCommission: 1.7, status: 'ACTIVE' };
          } else if (arr.includes('BT')) {
            codeMatch = { _id: 'comm_bt', operatorCode: 'BT', operatorName: 'BSNL TOPUP', serviceType: 'mobile', providerCommission: 5.0, retailerCommission: 3.0, companyCommission: 2.0, status: 'ACTIVE' };
          } else if (arr.includes('AT') || arr.includes('A')) {
            codeMatch = { _id: 'comm_at', operatorCode: 'AT', operatorName: 'Airtel', serviceType: 'mobile', providerCommission: 4.0, retailerCommission: 2.5, companyCommission: 1.5, status: 'ACTIVE' };
          } else if (arr.includes('JO') || arr.includes('RC')) {
            codeMatch = { _id: 'comm_jo', operatorCode: 'JO', operatorName: 'Jio', serviceType: 'mobile', providerCommission: 3.5, retailerCommission: 2.0, companyCommission: 1.5, status: 'ACTIVE' };
          }
        }
      }
      return {
        lean: jest.fn().mockResolvedValue(codeMatch),
      };
    });

    // Test Airtel
    const airtel = await commissionService.calculateCommission('A', 100, 'Airtel', 'mobile', { orderId: 'ORD_AT' });
    expect(Number.isFinite(airtel.providerCommissionAmount)).toBe(true);
    expect(Number.isFinite(airtel.retailerCommissionAmount)).toBe(true);
    expect(airtel.retailerCommissionPercentage).toBe(2.5);
    expect(airtel.retailerCommissionAmount).toBe(2.5);

    // Test Jio
    const jio = await commissionService.calculateCommission('RC', 200, 'Jio', 'mobile', { orderId: 'ORD_JO' });
    expect(jio.retailerCommissionPercentage).toBe(2.0);
    expect(jio.retailerCommissionAmount).toBe(4.0);

    // Test BSNL TOPUP
    const bsnlTopup = await commissionService.calculateCommission('BT', 10, 'BSNL TOPUP', 'mobile', { orderId: 'ORD_BT', planType: 'TOPUP' });
    expect(bsnlTopup.retailerCommissionPercentage).toBe(3.0);
    expect(bsnlTopup.retailerCommissionAmount).toBe(0.3);

    // Test BSNL STV
    const bsnlStv = await commissionService.calculateCommission('BR', 153, 'BSNL STV', 'mobile', { orderId: 'ORD_BR', planType: 'STV' });
    expect(bsnlStv.retailerCommissionPercentage).toBe(2.8);
    expect(bsnlStv.retailerCommissionAmount).toBe(4.28);
  });

  it('Step 6, 7 & 11: End-to-end successful recharge credits retailer wallet and creates CommissionHistory without NaN', async () => {
    OperatorCommission.findOne.mockReturnValue({
      lean: jest.fn().mockResolvedValue({
        _id: 'comm_at_rec',
        operatorCode: 'AT',
        operatorName: 'Airtel',
        serviceType: 'mobile',
        providerCommission: 4.0,
        retailerCommission: 2.5,
        companyCommission: 1.5,
        status: 'ACTIVE',
      }),
    });

    a1TopupProvider.recharge.mockResolvedValue({
      status: 'SUCCESS',
      providerTransactionId: 'TXN_A1_SUCCESS',
      message: 'SUCCESS',
    });

    mockReq.body = {
      mobileNumber: '9876543210',
      amount: 100,
      operatorId: '1',
      operatorName: 'Airtel',
      providerOperatorCode: 'AT',
      serviceType: 'mobile',
      mpin: '1234',
    };

    await executeRecharge(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(walletService.addBalance).toHaveBeenCalledWith('retailer_123', 2.5);
    expect(CommissionHistory.create).toHaveBeenCalledWith(expect.objectContaining({
      userId: 'retailer_123',
      operatorCode: 'AT',
      rechargeAmount: 100,
      providerCommissionPercentage: 4,
      providerCommissionAmount: 4,
      retailerCommissionPercentage: 2.5,
      retailerCommissionAmount: 2.5,
      companyProfitPercentage: 1.5,
      companyProfitAmount: 1.5,
    }));
  });

  it('Step 8: CommissionHistory creation failure does NOT change SUCCESS recharge to FAILED', async () => {
    OperatorCommission.findOne.mockReturnValue({
      lean: jest.fn().mockResolvedValue({
        _id: 'comm_at_rec',
        operatorCode: 'AT',
        operatorName: 'Airtel',
        serviceType: 'mobile',
        providerCommission: 4.0,
        retailerCommission: 2.5,
        companyCommission: 1.5,
        status: 'ACTIVE',
      }),
    });

    a1TopupProvider.recharge.mockResolvedValue({
      status: 'SUCCESS',
      providerTransactionId: 'TXN_SUCCESS_SAFE',
      message: 'Recharge successful',
    });

    CommissionHistory.create.mockRejectedValue(new Error('CommissionHistory write failure'));

    mockReq.body = {
      mobileNumber: '9876543210',
      amount: 100,
      operatorId: '4',
      operatorName: 'Airtel',
      providerOperatorCode: 'AT',
      serviceType: 'mobile',
      mpin: '1234',
    };

    await executeRecharge(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(mockRes.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Recharge successful',
    }));
  });
});
