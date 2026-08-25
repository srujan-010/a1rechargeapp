const mongoose = require('mongoose');
const OperatorCommission = require('../models/OperatorCommission');

// Default initial seeds if database is empty
const defaultSeedCommissions = [
  // Mobile
  { operatorCode: 'AT', operatorName: 'Airtel', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 2.0, retailerCommission: 1.00, companyCommission: 1.0, status: 'ACTIVE' },
  { operatorCode: 'JO', operatorName: 'Jio', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 1.5, retailerCommission: 0.80, companyCommission: 0.7, status: 'ACTIVE' },
  { operatorCode: 'VI', operatorName: 'Vi', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 3.5, retailerCommission: 2.70, companyCommission: 0.8, status: 'ACTIVE' },
  { operatorCode: 'BR', operatorName: 'BSNL', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 3.0, retailerCommission: 2.00, companyCommission: 1.0, status: 'ACTIVE' },
  
  // DTH
  { operatorCode: 'TP', operatorName: 'Tata Play', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 3.20, companyCommission: 0.8, status: 'ACTIVE' },
  { operatorCode: 'DISH', operatorName: 'Dish TV', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 3.25, companyCommission: 0.75, status: 'ACTIVE' },
  { operatorCode: 'SUN', operatorName: 'Sun Direct', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 3.25, companyCommission: 0.75, status: 'ACTIVE' },
  { operatorCode: 'AIRDTH', operatorName: 'Airtel DTH', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 3.20, companyCommission: 0.8, status: 'ACTIVE' },
  
  // Electricity / BBPS
  { operatorCode: 'BESCOM', operatorName: 'BESCOM Electricity', serviceType: 'electricity', commissionType: 'percentage', providerCommission: 0.8, retailerCommission: 0.40, companyCommission: 0.4, status: 'ACTIVE' },
  { operatorCode: 'TSSPDCL', operatorName: 'TSSPDCL Electricity', serviceType: 'electricity', commissionType: 'percentage', providerCommission: 0.8, retailerCommission: 0.40, companyCommission: 0.4, status: 'ACTIVE' },
  { operatorCode: 'TGSPDCL', operatorName: 'TGSPDCL Electricity', serviceType: 'electricity', commissionType: 'percentage', providerCommission: 0.8, retailerCommission: 0.40, companyCommission: 0.4, status: 'ACTIVE' },
  
  // Gas & FASTag
  { operatorCode: 'IGAS', operatorName: 'Indane Gas', serviceType: 'gas', commissionType: 'percentage', providerCommission: 1.0, retailerCommission: 0.50, companyCommission: 0.5, status: 'ACTIVE' },
  { operatorCode: 'PFAST', operatorName: 'Paytm FASTag', serviceType: 'fastag', commissionType: 'percentage', providerCommission: 0.6, retailerCommission: 0.30, companyCommission: 0.3, status: 'ACTIVE' },
];

/**
 * Ensures initial default commissions exist in MongoDB if database is empty.
 */
async function seedInitialCommissionsIfEmpty() {
  try {
    if (mongoose.connection.readyState !== 1) {
      return;
    }
    const count = await OperatorCommission.countDocuments();
    if (count === 0) {
      console.log('[CommissionEngine] Seeding initial operator commissions into MongoDB...');
      await OperatorCommission.insertMany(defaultSeedCommissions);
      console.log('[CommissionEngine] ✅ Successfully seeded initial commissions.');
    }
  } catch (err) {
    console.error('[CommissionEngine] Error seeding initial commissions:', err.message);
  }
}

// Automatically seed on module load
seedInitialCommissionsIfEmpty();

/**
 * @desc Get all active commission slabs directly from MongoDB
 * @route GET /api/commission/slabs or GET /api/commission
 */
const getActiveSlabs = async (req, res, next) => {
  try {
    await seedInitialCommissionsIfEmpty();

    const dbCommissions = await OperatorCommission.find({ status: 'ACTIVE' })
      .sort({ serviceType: 1, operatorName: 1 })
      .lean();

    const formattedSlabs = dbCommissions.map((item) => ({
      id: item._id.toString(),
      operatorCode: item.operatorCode,
      operatorName: item.operatorName,
      serviceType: item.serviceType || 'mobile',
      commissionType: item.commissionType || 'percentage',
      commissionValue: item.retailerCommission,
      providerCommission: item.providerCommission,
      companyCommission: item.companyCommission,
      effectiveFrom: item.createdAt ? new Date(item.createdAt).toISOString() : new Date().toISOString(),
      updatedAt: item.updatedAt ? new Date(item.updatedAt).toISOString() : new Date().toISOString(),
    }));

    // Categorized breakdown
    const categories = {
      mobile: formattedSlabs.filter((s) => s.serviceType === 'mobile'),
      dth: formattedSlabs.filter((s) => s.serviceType === 'dth'),
      electricity: formattedSlabs.filter((s) => s.serviceType === 'electricity' || s.serviceType === 'bbps'),
      gas: formattedSlabs.filter((s) => s.serviceType === 'gas'),
      fastag: formattedSlabs.filter((s) => s.serviceType === 'fastag'),
    };

    return res.status(200).json({
      success: true,
      data: formattedSlabs,
      categories: categories,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc Update operator commission in MongoDB (Admin Dashboard API)
 * @route PUT /api/commission/update
 */
const updateCommission = async (req, res, next) => {
  try {
    const { operatorCode, retailerCommission, providerCommission, companyCommission, status, serviceType } = req.body;

    if (!operatorCode) {
      res.status(400);
      throw new Error('operatorCode is required');
    }

    const updateFields = {};
    if (retailerCommission !== undefined) updateFields.retailerCommission = Number(retailerCommission);
    if (providerCommission !== undefined) updateFields.providerCommission = Number(providerCommission);
    if (companyCommission !== undefined) updateFields.companyCommission = Number(companyCommission);
    if (status !== undefined) updateFields.status = status;
    if (serviceType !== undefined) updateFields.serviceType = serviceType;

    const updated = await OperatorCommission.findOneAndUpdate(
      { operatorCode: operatorCode.toUpperCase() },
      { $set: updateFields },
      { new: true, upsert: true }
    ).lean();

    console.log(`[CommissionEngine] Updated commission for ${updated.operatorName} (${updated.operatorCode}) -> Retailer: ${updated.retailerCommission}%`);

    return res.status(200).json({
      success: true,
      message: `Commission updated successfully for ${updated.operatorName}`,
      data: {
        id: updated._id.toString(),
        operatorCode: updated.operatorCode,
        operatorName: updated.operatorName,
        serviceType: updated.serviceType,
        commissionType: updated.commissionType,
        commissionValue: updated.retailerCommission,
        providerCommission: updated.providerCommission,
        companyCommission: updated.companyCommission,
        updatedAt: updated.updatedAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

const getOperatorCodeAliases = (identifier = '') => {
  const clean = String(identifier || '').trim().toUpperCase();
  const map = {
    'A': ['A', 'AT', 'AIRTEL'],
    'AT': ['A', 'AT', 'AIRTEL'],
    'AIRTEL': ['A', 'AT', 'AIRTEL'],
    'RC': ['RC', 'JO', 'JIO', 'RELIANCE - JIO', 'RELIANCE JIO'],
    'JO': ['RC', 'JO', 'JIO', 'RELIANCE - JIO', 'RELIANCE JIO'],
    'JIO': ['RC', 'JO', 'JIO', 'RELIANCE - JIO', 'RELIANCE JIO'],
    'V': ['V', 'VI', 'VODAFONE', 'IDEA', 'I'],
    'VI': ['V', 'VI', 'VODAFONE', 'IDEA', 'I'],
    'VODAFONE': ['V', 'VI', 'VODAFONE', 'IDEA', 'I'],
    'BT': ['BT', 'BR', 'BS', 'BSNL', 'BSNL TOPUP', 'BSNL-TOPUP', 'BSNL STV', 'BSNL SPECIAL'],
    'BR': ['BT', 'BR', 'BS', 'BSNL', 'BSNL TOPUP', 'BSNL-TOPUP', 'BSNL STV', 'BSNL SPECIAL'],
    'BS': ['BT', 'BR', 'BS', 'BSNL', 'BSNL TOPUP', 'BSNL-TOPUP', 'BSNL STV', 'BSNL SPECIAL'],
    'BSNL': ['BT', 'BR', 'BS', 'BSNL', 'BSNL TOPUP', 'BSNL-TOPUP', 'BSNL STV', 'BSNL SPECIAL'],
    'BSNL TOPUP': ['BT', 'BR', 'BS', 'BSNL', 'BSNL TOPUP', 'BSNL-TOPUP', 'BSNL STV', 'BSNL SPECIAL'],
    'BSNL-TOPUP': ['BT', 'BR', 'BS', 'BSNL', 'BSNL TOPUP', 'BSNL-TOPUP', 'BSNL STV', 'BSNL SPECIAL'],
    'TP': ['TP', 'TTV', 'TATA PLAY', 'TATA SKY'],
    'TTV': ['TP', 'TTV', 'TATA PLAY', 'TATA SKY'],
    'DISH': ['DISH', 'DTV', 'DISH TV'],
    'DTV': ['DISH', 'DTV', 'DISH TV'],
    'SUN': ['SUN', 'STV', 'SUN DIRECT'],
    'STV': ['SUN', 'STV', 'SUN DIRECT'],
    'VTV': ['VTV', 'VIDEOCON', 'D2H', 'VIDEOCON D2H'],
    'ATV': ['ATV', 'AIRDTH', 'AIRTEL DTH'],
  };

  if (map[clean]) return map[clean];

  if (clean.includes('BSNL')) return ['BT', 'BR', 'BS', 'BSNL', 'BSNL TOPUP', 'BSNL-TOPUP', 'BSNL STV', 'BSNL SPECIAL'];
  if (clean.includes('AIRTEL')) return ['A', 'AT', 'AIRTEL', 'AIRDTH', 'ATV'];
  if (clean.includes('JIO') || clean.includes('RELIANCE')) return ['RC', 'JO', 'JIO', 'RELIANCE - JIO', 'RELIANCE JIO'];
  if (clean.includes('VI') || clean.includes('VODAFONE') || clean.includes('IDEA')) return ['V', 'VI', 'VODAFONE', 'IDEA', 'I'];
  if (clean.includes('TATA')) return ['TP', 'TTV', 'TATA PLAY', 'TATA SKY'];
  if (clean.includes('DISH')) return ['DISH', 'DTV', 'DISH TV'];
  if (clean.includes('SUN')) return ['SUN', 'STV', 'SUN DIRECT'];
  if (clean.includes('VIDEOCON') || clean.includes('D2H')) return ['VTV', 'VIDEOCON', 'D2H', 'VIDEOCON D2H'];

  return [clean];
};

const getCommissionForOperator = async (operatorIdentifier) => {
  if (!operatorIdentifier) return null;
  const aliases = getOperatorCodeAliases(operatorIdentifier);
  const cleanName = String(operatorIdentifier).trim();

  if (mongoose.connection.readyState !== 1) {
    const found = defaultSeedCommissions.find(s => 
      s.status === 'ACTIVE' && 
      (aliases.includes(s.operatorCode.toUpperCase()) || s.operatorName.toLowerCase() === cleanName.toLowerCase())
    );
    return found || null;
  }

  let record = await OperatorCommission.findOne({
    status: 'ACTIVE',
    $or: [
      { operatorCode: { $in: aliases } },
      { operatorName: { $regex: new RegExp(`^${cleanName}$`, 'i') } },
      { operatorName: { $regex: new RegExp(cleanName, 'i') } }
    ]
  }).lean();

  return record;
};

const getCommissionForOperatorAndService = async (serviceType = 'mobile', operatorIdentifier = '') => {
  if (!operatorIdentifier) return null;
  const sType = String(serviceType).toLowerCase().trim();
  const aliases = getOperatorCodeAliases(operatorIdentifier);
  const cleanName = String(operatorIdentifier).trim().toLowerCase();

  if (mongoose.connection.readyState !== 1) {
    const foundExact = defaultSeedCommissions.find(s => 
      s.status === 'ACTIVE' && 
      (!sType || s.serviceType === sType) &&
      (aliases.includes(s.operatorCode.toUpperCase()) || s.operatorName.toLowerCase() === cleanName || s.operatorName.toLowerCase().includes(cleanName))
    );
    return foundExact || null;
  }

  let record = await OperatorCommission.findOne({
    status: 'ACTIVE',
    serviceType: sType,
    $or: [
      { operatorCode: { $in: aliases } },
      { operatorName: { $regex: new RegExp(`^${cleanName}$`, 'i') } },
      { operatorName: { $regex: new RegExp(cleanName, 'i') } }
    ]
  }).lean();

  if (!record) {
    record = await OperatorCommission.findOne({
      status: 'ACTIVE',
      $or: [
        { operatorCode: { $in: aliases } },
        { operatorName: { $regex: new RegExp(`^${cleanName}$`, 'i') } },
        { operatorName: { $regex: new RegExp(cleanName, 'i') } }
      ]
    }).lean();
  }

  return record;
};

module.exports = {
  getActiveSlabs,
  updateCommission,
  getCommissionForOperator,
  getCommissionForOperatorAndService,
  getOperatorCodeAliases,
};
