const FastagOperator = require('../models/FastagOperator');
const planApiService = require('../services/planapi.service');

// @desc    Get all fastag operators
// @route   GET /api/fastag/operators
// @access  Public
exports.getOperators = async (req, res, next) => {
  try {
    const { search, page = 1, limit = 50 } = req.query;

    let query = { isActive: true };
    if (search) {
      query.name = { $regex: search, $options: 'i' };
    }

    const startIndex = (parseInt(page) - 1) * parseInt(limit);
    const total = await FastagOperator.countDocuments(query);
    const operators = await FastagOperator.find(query)
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

const currentBillPaymentService = require('../services/currentBillPayment.service');

// @desc    Fetch fastag details
// @route   POST /api/fastag/fetch
// @access  Public
exports.fetchDetails = async (req, res, next) => {
  try {
    const { billerId, parameters } = req.body;

    if (!billerId) return res.status(400).json({ success: false, message: 'billerId is required' });
    if (!parameters || Object.keys(parameters).length === 0) {
      return res.status(400).json({ success: false, message: 'Invalid details. No details found.' });
    }

    let operator;
    if (isNaN(billerId)) {
      operator = await FastagOperator.findById(billerId);
    } else {
      operator = await FastagOperator.findOne({ 'planApi.operatorCode': billerId });
      if (!operator) {
        operator = await FastagOperator.findOne({ operatorCode: billerId });
      }
    }
    
    if (!operator) {
      return res.status(404).json({ success: false, message: 'FASTag issuer not found' });
    }

    const planApiCode = operator.planApi?.operatorCode;
    if (!planApiCode) {
      return res.status(400).json({ success: false, message: 'Operator fetch code not configured' });
    }

    let planApiResponse;
    try {
      planApiResponse = await planApiService.fetchFastagDetails(planApiCode, parameters);
    } catch (apiError) {
      return res.status(400).json({ 
        success: false, 
        message: 'Provider API failed to fetch FASTag details.' 
      });
    }

    const rawData = planApiResponse.data || {};
    if (!planApiResponse.success) {
      return res.status(400).json({ success: false, message: rawData.message || rawData.Message || 'Failed to fetch FASTag details from provider' });
    }

    const details = rawData.BILLDEATILS || rawData.BILLDETAILS || rawData.data || rawData;

    const responseData = {
      billerId: billerId,
      billerName: operator.name,
      customerName: details.customername || details.CustomerName || details.name || details.Name || 'Vehicle Owner',
      vehicleNumber: parameters.vehicleNumber || parameters.vehicle_number || Object.values(parameters)[0] || 'Unknown',
      status: 'ACTIVE',
      rawProviderResponse: rawData
    };

    res.status(200).json({
      success: true,
      data: responseData
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Pay a fastag bill/recharge
// @route   POST /api/fastag/pay
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

    let operator;
    if (isNaN(billerId)) {
      operator = await FastagOperator.findById(billerId);
    } else {
      operator = await FastagOperator.findOne({ 'planApi.operatorCode': billerId });
      if (!operator) {
        operator = await FastagOperator.findOne({ operatorCode: billerId });
      }
    }
    
    if (!operator) {
      return res.status(404).json({ success: false, message: 'FASTag operator not found' });
    }

    const a1TopupCode = operator.a1Topup?.operatorCode;
    if (!a1TopupCode) {
      return res.status(400).json({ success: false, message: 'Operator payment code not configured' });
    }

    const amount = amountPaise / 100;

    const paymentResponse = await currentBillPaymentService.executePayment({
      user: req.user,
      mpin: mpin,
      orderIdPrefix: 'FT',
      consumerIdentifier: customerIdentifier || '0000000000',
      amount,
      operatorCode: a1TopupCode,
      serviceType: 'FASTag'
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

// @desc    Check status of a fastag payment
// @route   GET /api/fastag/status/:orderId
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
