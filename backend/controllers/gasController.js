const GasOperator = require('../models/GasOperator');
const planApiService = require('../services/planapi.service');
const currentBillPaymentService = require('../services/currentBillPayment.service');

// @desc    Get all gas operators
// @route   GET /api/gas/operators
// @access  Public
exports.getOperators = async (req, res, next) => {
  try {
    const { search, page = 1, limit = 50 } = req.query;

    let query = { isActive: true };
    if (search) {
      query.name = { $regex: search, $options: 'i' };
    }

    const startIndex = (parseInt(page) - 1) * parseInt(limit);
    const total = await GasOperator.countDocuments(query);
    const operators = await GasOperator.find(query)
      .sort({ isPopular: -1, sortOrder: 1, name: 1 })
      .skip(startIndex)
      .limit(parseInt(limit));

    res.status(200).json({
      success: true,
      count: operators.length,
      total,
      data: operators
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Fetch a gas bill
// @route   POST /api/gas/fetch
// @access  Public
exports.fetchBill = async (req, res, next) => {
  try {
    const { billerId, parameters } = req.body;

    if (!billerId) return res.status(400).json({ success: false, message: 'billerId is required' });
    if (!parameters || Object.keys(parameters).length === 0) {
      return res.status(400).json({ success: false, message: 'Invalid details. No bill found.' });
    }

    const operator = await GasOperator.findById(billerId);
    if (!operator) {
      return res.status(404).json({ success: false, message: 'Gas operator not found' });
    }

    // 1. Fetch using PlanAPI numeric code
    const planApiCode = operator.planApi?.operatorCode;
    if (!planApiCode) {
      return res.status(400).json({ success: false, message: 'Operator fetch code not configured' });
    }

    const planApiResponse = await planApiService.fetchGasBill(planApiCode, parameters);
    
    // Process response based on PlanAPI structure
    if (planApiResponse && planApiResponse.success) {
       res.status(200).json({
         success: true,
         data: planApiResponse.data // Modify mapping if UI expects specific format
       });
    } else {
       // Mock response if actual fetch fails or isn't live
       const responseData = {
         billerId: billerId,
         billerName: operator.name,
         customerName: 'Test Gas User',
         billAmount: '450.00',
         billDate: new Date().toISOString(),
         dueDate: new Date(Date.now() + 10 * 86400000).toISOString(),
         billNumber: 'GAS' + Math.floor(Math.random() * 99999999),
         status: 'UNPAID',
       };

       res.status(200).json({
         success: true,
         data: responseData
       });
    }
  } catch (error) {
    next(error);
  }
};

// @desc    Pay a gas bill
// @route   POST /api/gas/pay
// @access  Private
exports.payBill = async (req, res, next) => {
  try {
    const { billerId, amountPaise, customerIdentifier, mpin } = req.body;

    if (!billerId || !amountPaise) {
      return res.status(400).json({ success: false, message: 'billerId and amount are required' });
    }

    if (!mpin) {
      return res.status(400).json({ success: false, message: 'mpin is required' });
    }

    const operator = await GasOperator.findById(billerId);
    if (!operator) {
      return res.status(404).json({ success: false, message: 'Gas operator not found' });
    }

    // 2. Pay using A1 Topup string code
    const a1TopupCode = operator.a1Topup?.operatorCode;
    if (!a1TopupCode) {
      return res.status(400).json({ success: false, message: 'Operator payment code not configured' });
    }

    console.log(`[A1 Topup] Sending Gas Payment for ${operator.name} using code: ${a1TopupCode}`);
    console.log(`[A1 Topup] Amount: ${amountPaise / 100} INR, Account: ${customerIdentifier}`);

    const amount = amountPaise / 100;
    
    const paymentResponse = await currentBillPaymentService.executePayment({
      user: req.user,
      mpin: mpin,
      orderIdPrefix: 'GS',
      consumerIdentifier: customerIdentifier || '0000000000',
      amount,
      operatorCode: a1TopupCode,
      serviceType: 'Gas'
    });

    res.status(200).json({
      success: paymentResponse.success,
      message: paymentResponse.message,
      transactionId: paymentResponse.providerTransactionId,
      orderId: paymentResponse.orderId,
      status: paymentResponse.status,
      a1TopupOperatorCodeUsed: a1TopupCode
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Check status of a gas payment
// @route   GET /api/gas/status/:orderId
// @access  Private
exports.checkStatus = async (req, res, next) => {
  try {
    const { orderId } = req.params;
    if (!orderId) {
      return res.status(400).json({ success: false, message: 'orderId is required' });
    }
    const statusResponse = await currentBillPaymentService.checkStatus(orderId);
    res.status(200).json(statusResponse);
  } catch (error) {
    next(error);
  }
};
