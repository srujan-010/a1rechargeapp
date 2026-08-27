const mongoose = require('mongoose');
const crypto = require('crypto');
const RechargeTransaction = require('../models/RechargeTransaction');
const Transaction = require('../models/Transaction');
const CommissionHistory = require('../models/CommissionHistory');
const User = require('../models/User');
const ProviderOperator = require('../models/ProviderOperator');
const commissionService = require('../services/commission/commission.service');
const notificationService = require('../services/notification.service');
const ledgerService = require('../services/ledger/ledger.service');
const rechargePoller = require('../utils/rechargePoller');
const { 
  calculateRechargePayable, 
  verifyRazorpayRechargePayment 
} = require('../controllers/recharge.controller');
const a1TopupProvider = require('../services/providers/a1topup/provider.service');

jest.mock('../services/providers/a1topup/provider.service');
jest.mock('../services/commission/commission.service');
jest.mock('../services/notification.service');
jest.mock('../services/ledger/ledger.service');
jest.mock('../utils/rechargePoller');
jest.mock('../models/RechargeTransaction');
jest.mock('../models/Transaction');
jest.mock('../models/CommissionHistory');
jest.mock('../models/User');
jest.mock('../models/ProviderOperator');

jest.setTimeout(10000);

describe('Razorpay Recharge Checkout & Commission Accounting Tests', () => {
  let mockReq, mockRes, mockNext;
  let testUser;

  beforeEach(() => {
    jest.clearAllMocks();

    process.env.RAZORPAY_KEY_ID = 'rzp_live_TT5zU7nK3KcH8Y';
    process.env.RAZORPAY_KEY_SECRET = 'v45oD145W4CRty7hAWrjJ1cq';

    testUser = {
      _id: new mongoose.Types.ObjectId(),
      name: 'Test Retailer',
      phone: '9421729714',
      role: 'retailer',
    };

    mockReq = {
      user: testUser,
      body: {},
    };

    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    mockNext = jest.fn();

    commissionService.calculateCommission.mockResolvedValue({
      providerCommissionPercentage: 3.0,
      providerCommissionAmount: 3.0,
      retailerCommissionPercentage: 2.0,
      retailerCommissionAmount: 2.0,
      companyProfitPercentage: 1.0,
      companyProfitAmount: 1.0,
    });

    ledgerService.logTransaction.mockResolvedValue({ _id: new mongoose.Types.ObjectId() });
    CommissionHistory.findOne.mockResolvedValue(null);
    CommissionHistory.create.mockResolvedValue({});
    User.findById.mockResolvedValue({ _id: testUser._id, name: 'Test Retailer' });
    ProviderOperator.findById.mockResolvedValue({ code: 'BT', name: 'BSNL TOPUP' });
    ProviderOperator.findOne.mockResolvedValue({ code: 'BT', name: 'BSNL TOPUP' });
  });

  describe('1. calculateRechargePayable', () => {
    it('calculates server-side payable amount correctly', async () => {
      mockReq.body = {
        mobileNumber: '9421729714',
        amount: 100,
        operatorCode: 'BSNL',
        operatorName: 'BSNL TOPUP',
        serviceType: 'mobile',
      };

      await calculateRechargePayable(mockReq, mockRes, mockNext);

      expect(mockRes.status).toHaveBeenCalledWith(200);
      const resData = mockRes.json.mock.calls[0][0];
      expect(resData.success).toBe(true);
      expect(resData.data.rechargeAmount).toBe(100);
      expect(resData.data.payableAmount).toBe(98);
      expect(resData.data.commissionAmount).toBe(2);
    });
  });

  describe('2. verifyRazorpayRechargePayment HMAC signature verification', () => {
    it('verifies valid HMAC signature and processes recharge', async () => {
      const orderId = 'order_test_12345';
      const paymentId = 'pay_test_67890';
      const secret = 'v45oD145W4CRty7hAWrjJ1cq';
      
      const signature = crypto
        .createHmac('sha256', secret)
        .update(`${orderId}|${paymentId}`)
        .digest('hex');

      const mockTx = {
        _id: new mongoose.Types.ObjectId(),
        userId: testUser._id,
        orderId: 'A1R_TEST_001',
        mobileNumber: '9421729714',
        amount: 100,
        payableAmount: 98,
        commissionAmount: 2,
        status: 'PAYMENT_PENDING',
        razorpayOrderId: orderId,
        operatorCode: 'BSNL',
        save: jest.fn().mockResolvedValue(true),
      };

      RechargeTransaction.findOne.mockResolvedValue(mockTx);
      Transaction.findOne.mockResolvedValue(null);

      a1TopupProvider.recharge.mockResolvedValue({
        success: true,
        status: 'SUCCESS',
        providerTransactionId: 'A1TRANS12345',
      });

      mockReq.body = {
        internalTransactionId: mockTx._id.toString(),
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      };

      await verifyRazorpayRechargePayment(mockReq, mockRes, mockNext);

      expect(mockRes.status).toHaveBeenCalledWith(200);
      const response = mockRes.json.mock.calls[0][0];
      expect(response.success).toBe(true);
      expect(['processing', 'success']).toContain(response.data.status);
    });

    it('rejects tampered signature in production mode', async () => {
      const oldEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'production';

      const mockTx = {
        _id: new mongoose.Types.ObjectId(),
        userId: testUser._id,
        orderId: 'A1R_TEST_002',
        status: 'PAYMENT_PENDING',
        razorpayOrderId: 'order_test_999',
        save: jest.fn().mockResolvedValue(true),
      };

      RechargeTransaction.findOne.mockResolvedValue(mockTx);
      Transaction.findOne.mockResolvedValue(null);

      mockReq.body = {
        internalTransactionId: mockTx._id.toString(),
        razorpayOrderId: 'order_test_999',
        razorpayPaymentId: 'pay_test_999',
        razorpaySignature: 'invalid_tampered_signature',
      };

      await verifyRazorpayRechargePayment(mockReq, mockRes, mockNext);

      expect(mockRes.status).toHaveBeenCalledWith(400);
      const response = mockRes.json.mock.calls[0][0];
      expect(response.success).toBe(false);
      expect(response.code).toBe('INVALID_SIGNATURE');

      process.env.NODE_ENV = oldEnv;
    });
  });
});
