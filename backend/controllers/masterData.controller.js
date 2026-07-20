const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');

// ==========================================
// PUBLIC APIs (For Retailers/Flutter App)
// ==========================================

// @desc    Get all active operators (optional filter by service)
// @route   GET /api/operators
// @access  Public / Retailer
exports.getOperators = async (req, res) => {
  try {
    const { service } = req.query;
    let query = { status: true };
    
    if (service) {
      query.serviceType = service;
    }

    const operators = await ProviderOperator.find(query)
      .sort({ displayOrder: 1, name: 1 })
      .select('name serviceType provider code displayOrder');

    res.json({
      success: true,
      count: operators.length,
      data: operators
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server Error', error: error.message });
  }
};

// @desc    Get all active circles
// @route   GET /api/circles
// @access  Public / Retailer
exports.getCircles = async (req, res) => {
  try {
    const circles = await ProviderCircle.find({ status: true })
      .sort({ state: 1 })
      .select('state provider code');

    res.json({
      success: true,
      count: circles.length,
      data: circles
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server Error', error: error.message });
  }
};

// @desc    Offline resolver to auto-guess Operator and Circle by phone number prefix
// @route   GET /api/master/resolve?mobile=...
// @access  Public / Retailer
exports.resolveOperatorAndCircle = async (req, res) => {
  try {
    const { mobile } = req.query;
    if (!mobile || mobile.length < 10) {
      return res.status(400).json({ success: false, message: 'Invalid mobile number' });
    }

    // Default Fallbacks
    let operatorCode = 'RC'; // Jio
    let circleCode = '4'; // Maharashtra

    // Simple heuristic offline resolver (for demonstration in lieu of live HLR)
    const prefix = mobile.substring(0, 4);
    const firstDigit = mobile.charAt(0);

    if (firstDigit === '9') {
      operatorCode = 'A'; // Airtel
      circleCode = '1'; // Delhi
    } else if (firstDigit === '8') {
      operatorCode = 'V'; // Vi
      circleCode = '3'; // Kolkata
    } else if (firstDigit === '7') {
      operatorCode = 'RC'; // Jio
      circleCode = '4'; // Maharashtra
    }

    // Look them up in DB
    const operator = await ProviderOperator.findOne({ code: operatorCode, provider: 'A1Topup', status: true });
    const circle = await ProviderCircle.findOne({ code: circleCode, provider: 'A1Topup', status: true });

    res.json({
      success: true,
      data: {
        operator: operator || await ProviderOperator.findOne({ status: true }),
        circle: circle || await ProviderCircle.findOne({ status: true }),
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server Error', error: error.message });
  }
};

// ==========================================
// ADMIN APIs (CRUD Operations)
// ==========================================

// @desc    Get all operators (including inactive)
// @route   GET /api/admin/operators
// @access  Admin
exports.adminGetOperators = async (req, res) => {
  try {
    const operators = await ProviderOperator.find().sort({ provider: 1, displayOrder: 1 });
    res.json({ success: true, count: operators.length, data: operators });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server Error', error: error.message });
  }
};

// @desc    Create new operator
// @route   POST /api/admin/operators
// @access  Admin
exports.adminCreateOperator = async (req, res) => {
  try {
    const operator = await ProviderOperator.create(req.body);
    res.status(201).json({ success: true, data: operator });
  } catch (error) {
    res.status(400).json({ success: false, message: 'Invalid data', error: error.message });
  }
};

// @desc    Update operator
// @route   PUT /api/admin/operators/:id
// @access  Admin
exports.adminUpdateOperator = async (req, res) => {
  try {
    const operator = await ProviderOperator.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true
    });
    
    if (!operator) {
      return res.status(404).json({ success: false, message: 'Operator not found' });
    }
    
    res.json({ success: true, data: operator });
  } catch (error) {
    res.status(400).json({ success: false, message: 'Invalid data', error: error.message });
  }
};

// @desc    Delete operator
// @route   DELETE /api/admin/operators/:id
// @access  Admin
exports.adminDeleteOperator = async (req, res) => {
  try {
    const operator = await ProviderOperator.findByIdAndDelete(req.params.id);
    if (!operator) {
      return res.status(404).json({ success: false, message: 'Operator not found' });
    }
    res.json({ success: true, data: {} });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server Error', error: error.message });
  }
};

// @desc    Get all circles (including inactive)
// @route   GET /api/admin/circles
// @access  Admin
exports.adminGetCircles = async (req, res) => {
  try {
    const circles = await ProviderCircle.find().sort({ provider: 1, state: 1 });
    res.json({ success: true, count: circles.length, data: circles });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server Error', error: error.message });
  }
};

// @desc    Create new circle
// @route   POST /api/admin/circles
// @access  Admin
exports.adminCreateCircle = async (req, res) => {
  try {
    const circle = await ProviderCircle.create(req.body);
    res.status(201).json({ success: true, data: circle });
  } catch (error) {
    res.status(400).json({ success: false, message: 'Invalid data', error: error.message });
  }
};

// @desc    Update circle
// @route   PUT /api/admin/circles/:id
// @access  Admin
exports.adminUpdateCircle = async (req, res) => {
  try {
    const circle = await ProviderCircle.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true
    });
    
    if (!circle) {
      return res.status(404).json({ success: false, message: 'Circle not found' });
    }
    
    res.json({ success: true, data: circle });
  } catch (error) {
    res.status(400).json({ success: false, message: 'Invalid data', error: error.message });
  }
};

// @desc    Delete circle
// @route   DELETE /api/admin/circles/:id
// @access  Admin
exports.adminDeleteCircle = async (req, res) => {
  try {
    const circle = await ProviderCircle.findByIdAndDelete(req.params.id);
    if (!circle) {
      return res.status(404).json({ success: false, message: 'Circle not found' });
    }
    res.json({ success: true, data: {} });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server Error', error: error.message });
  }
};
