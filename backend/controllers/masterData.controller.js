const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
const fs = require('fs');
const path = require('path');

// ==========================================
// PUBLIC APIs (For Retailers/Flutter App)
// ==========================================

// @desc    Get all active operators (optional filter by service)
// @route   GET /api/operators
// @access  Public / Retailer
exports.getOperators = async (req, res) => {
  try {
    const { service } = req.query;
    console.log('req.query:', req.query);
    
    // Load central operator registry
    const registryPath = path.join(__dirname, '../../assets/operator_registry.json');
    let operatorsData = {};
    if (fs.existsSync(registryPath)) {
      const raw = fs.readFileSync(registryPath, 'utf8');
      operatorsData = JSON.parse(raw);
    } else {
      console.log('operator_registry.json not found at:', registryPath);
    }

    let uniqueOperators = [];
    
    if (service) {
      let serviceKey = service.toUpperCase();
      if (serviceKey === 'MOBILE') {
        serviceKey = 'PREPAID';
      }
      
      if (operatorsData[serviceKey]) {
        uniqueOperators = operatorsData[serviceKey].filter(op => op.active !== false);
      }
    } else {
      // Flatten all categories
      Object.keys(operatorsData).forEach(key => {
        const activeOps = operatorsData[key].filter(op => op.active !== false);
        uniqueOperators.push(...activeOps);
      });
    }

    // Map the JSON structure to match what the frontend expects
    // Frontend expects: { name, serviceType, code, _id/id }
    uniqueOperators = uniqueOperators.map(op => ({
      name: op.name,
      serviceType: op.service,
      code: op.code,
      shortCode: op.code.toString(),
      status: op.active,
      id: op.name.toLowerCase().replace(/\s+/g, '-')
    }));

    console.log('Number of unique operators returned:', uniqueOperators.length);

    res.json({
      success: true,
      count: uniqueOperators.length,
      data: uniqueOperators
    });
  } catch (error) {
    console.error('Error fetching operators:', error);
    res.status(500).json({ success: false, message: 'Server Error', error: error.message });
  }
};

// @desc    Get all active circles
// @route   GET /api/circles
// @access  Public / Retailer
exports.getCircles = async (req, res) => {
  try {
    // Define a basic Circle Registry map for PlanAPI based on provided list
    const circleRegistry = {
      'manipur': '106',
      'jharkhand': '105',
      'mizzoram': '104',
      'meghalay': '103',
      'goa': '102',
      'chhatisgarh': '101', 
      'tripura': '100',
      'sikkim': '99',
      'andhra pradesh': '49',
      'kerala': '95',
      'tamil nadu': '94', 
      'chennai': '40',
      'karnataka': '06',
      'bihar': '52', 
      'north east': '16',
      'assam': '56',
      'orissa': '53',
      'west bengal': '51',
      'kolkata': '31',
      'rajasthan': '70',
      'madhya pradesh': '93',
      'gujarat': '98',
      'maharashtra': '90',
      'mumbai': '92',
      'up east': '54',
      'jammu & kashmir': '55',
      'haryana': '96',
      'himachal pradesh': '03',
      'punjab': '02',
      'up west': '97',
      'delhi': '10',
    };

    const circles = Object.entries(circleRegistry).map(([state, code]) => ({
      id: state.replace(/\s+/g, '-'),
      state: state.split(' ').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' '),
      code: code,
      provider: 'PlanAPI',
      status: true
    }));

    res.json({
      success: true,
      count: circles.length,
      data: circles
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
