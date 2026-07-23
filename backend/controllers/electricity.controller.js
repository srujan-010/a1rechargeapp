const ElectricityOperator = require('../models/ElectricityOperator');
const ElectricityDistrict = require('../models/ElectricityDistrict');
const State = require('../models/State');

// @desc    Get all electricity operators (with search & pagination)
// @route   GET /api/electricity/operators
// @access  Public
exports.getOperators = async (req, res, next) => {
  try {
    const { state, stateCode, search, page = 1, limit = 50 } = req.query;

    console.log(`\n=========================================================`);
    console.log(`[GET OPERATORS] Request received from Flutter`);
    console.log(`State Parameter: ${state}`);
    console.log(`StateCode Parameter: ${stateCode}`);

    // Build query
    let query = { isActive: true };
    
    if (stateCode) {
      query.stateCode = stateCode;
    } else if (state) {
      query.state = state;
    }

    if (search) {
      query.name = { $regex: search, $options: 'i' };
    }

    const startIndex = (parseInt(page) - 1) * parseInt(limit);
    const total = await ElectricityOperator.countDocuments(query);

    const operators = await ElectricityOperator.find(query)
      .sort({ isPopular: -1, sortOrder: 1, name: 1 })
      .skip(startIndex)
      .limit(parseInt(limit));

    console.log(`MongoDB Query executed: ${JSON.stringify(query)}`);
    console.log(`Number of operators found: ${total}`);
    
    const operatorNames = operators.map(op => op.name).join(', ');
    console.log(`Operators returned: ${operatorNames}`);
    console.log(`=========================================================\n`);

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

// @desc    Get single electricity operator
// @route   GET /api/electricity/operators/:id
// @access  Public
exports.getOperator = async (req, res, next) => {
  try {
    const operator = await ElectricityOperator.findById(req.params.id);

    if (!operator) {
      return res.status(404).json({ success: false, message: 'Operator not found' });
    }

    res.status(200).json({
      success: true,
      data: operator
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get single electricity operator by operatorCode
// @route   GET /api/electricity/operators/code/:operatorCode
// @access  Public
exports.getOperatorByCode = async (req, res, next) => {
  try {
    const operator = await ElectricityOperator.findOne({ operatorCode: req.params.operatorCode });

    if (!operator) {
      return res.status(404).json({ success: false, message: 'Operator not found' });
    }

    res.status(200).json({
      success: true,
      data: operator
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get districts for an operator
// @route   GET /api/electricity/operators/:operatorCode/districts
// @access  Public
exports.getDistrictsByOperatorCode = async (req, res, next) => {
  try {
    const districts = await ElectricityDistrict.find({ operatorCode: req.params.operatorCode })
      .sort({ districtName: 1 });

    res.status(200).json({
      success: true,
      count: districts.length,
      data: districts
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get all unique states
// @route   GET /api/electricity/states
// @access  Public
exports.getStates = async (req, res, next) => {
  try {
    const statesData = await State.find({ isActive: true }).sort({ sortOrder: 1, name: 1 });
    
    // The flutter app expects an array of strings: ['Andhra Pradesh', 'Assam', ...]
    const validStates = statesData.map(s => s.name);

    res.status(200).json({
      success: true,
      count: validStates.length,
      data: validStates
    });
  } catch (error) {
    next(error);
  }
};

const planApiService = require('../services/planapi.service');

// @desc    Fetch a bill (mock endpoint replacing dart mock)
// @route   POST /api/electricity/fetch
// @access  Public
exports.fetchBill = async (req, res, next) => {
  try {
    const { billerId, parameters } = req.body;

    console.log('\n==================================================');
    console.log('[ELECTRICITY CONTROLLER] Incoming Request: fetchBill');
    console.log('Query/Body Parameters:', { billerId, parameters });

    if (!billerId) {
      return res.status(400).json({ success: false, message: 'billerId is required' });
    }

    if (!parameters || Object.keys(parameters).length === 0) {
      return res.status(400).json({ success: false, message: 'Invalid details. No bill found for these parameters.' });
    }

    const hasInvalidParam = Object.values(parameters).some(v => !v || v.trim() === '' || v === '0000000000');
    if (hasInvalidParam) {
      return res.status(400).json({ success: false, message: 'Invalid details. No bill found for these parameters.' });
    }

    // Call PlanAPI
    console.log('[ELECTRICITY CONTROLLER] Calling PlanAPI...');
    
    let planApiResponse;
    try {
      planApiResponse = await planApiService.fetchElectricityBill(billerId, parameters);
    } catch (apiError) {
      console.log('[ELECTRICITY CONTROLLER] PlanAPI Call Failed:', apiError.message);
      
      let providerMessage = 'Provider API failed to fetch bill.';
      let statusCode = 502;
      
      if (apiError.response && apiError.response.data) {
        const rawData = apiError.response.data;
        providerMessage = rawData.Message || rawData.message || rawData.ERRORMSG || rawData.error || providerMessage;
        statusCode = apiError.response.status; // Return the actual provider status code if desired, but Flutter might expect 400/502. 
        // We'll use 400 for bad request/404s so Flutter shows it properly as a validation exception.
        if (statusCode === 404) statusCode = 400; 
      }

      console.log('[ELECTRICITY CONTROLLER] Extracted Provider Message:', providerMessage);

      // Return the exact provider message
      return res.status(statusCode).json({ 
        success: false, 
        providerMessage: providerMessage,
        message: providerMessage, // include message for backwards compatibility
        error: apiError.message,
        stack: apiError.stack
      });
    }

    console.log('[ELECTRICITY CONTROLLER] Received PlanAPI Response.');

    let operator;
    if (isNaN(billerId)) {
      operator = await ElectricityOperator.findById(billerId);
    } else {
      operator = await ElectricityOperator.findOne({ 'planApi.operatorCode': billerId });
      if (!operator) {
        // Fallback to legacy field just in case
        operator = await ElectricityOperator.findOne({ operatorCode: billerId });
      }
    }
    const billerName = operator ? operator.name : 'Unknown Provider';

    // Parse the PlanAPI response
    // PlanAPI often returns details inside BILLDEATILS (misspelled) or BILLDETAILS or data
    const rawData = planApiResponse.data || {};
    
    // Some providers might return an error but with 200 OK.
    if (!planApiResponse.success) {
      return res.status(400).json({ success: false, message: rawData.message || rawData.Message || 'Failed to fetch bill from provider' });
    }

    const details = rawData.BILLDEATILS || rawData.BILLDETAILS || rawData.data || rawData;

    const billNumber = details.billnumber || details.BillNumber || details.bill_number || ('B' + Math.floor(Math.random() * 99999999).toString().padStart(8, '0'));
    const amount = details.amount || details.Amount || details.DueAmount || details.dueamount || details.billamount || details.BillAmount || '0.00';
    const customerName = details.customername || details.CustomerName || details.name || details.Name || 'Not Available';
    const dueDate = details.duedate || details.DueDate || details.due_date || new Date(Date.now() + 10 * 86400000).toISOString();
    const billDate = details.billdate || details.BillDate || details.bill_date || new Date(Date.now() - 5 * 86400000).toISOString();

    const responseData = {
      billerId: billerId,
      billerName: billerName,
      customerName: customerName,
      billAmount: amount, // in rupees
      billDate: billDate,
      dueDate: dueDate,
      billNumber: billNumber,
      status: 'UNPAID',
      rawProviderResponse: rawData
    };

    console.log('[ELECTRICITY CONTROLLER] Final Backend Response to Flutter:', responseData);
    console.log('==================================================\n');

    res.status(200).json({
      success: true,
      data: responseData
    });
  } catch (error) {
    next(error);
  }
};

