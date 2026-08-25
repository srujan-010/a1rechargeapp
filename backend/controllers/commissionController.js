const mongoose = require('mongoose');
const OperatorCommission = require('../models/OperatorCommission');

// Default initial BUSINESS seed slabs
const defaultBusinessSeedCommissions = [
  // Mobile
  { accountType: 'BUSINESS', operatorCode: 'AT', operatorName: 'Airtel', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 2.0, retailerCommission: 1.00, companyCommission: 1.0, status: 'ACTIVE' },
  { accountType: 'BUSINESS', operatorCode: 'JO', operatorName: 'Jio', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 1.5, retailerCommission: 0.80, companyCommission: 0.7, status: 'ACTIVE' },
  { accountType: 'BUSINESS', operatorCode: 'VI', operatorName: 'Vi', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 3.5, retailerCommission: 2.70, companyCommission: 0.8, status: 'ACTIVE' },
  { accountType: 'BUSINESS', operatorCode: 'BR', operatorName: 'BSNL', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 3.0, retailerCommission: 2.00, companyCommission: 1.0, status: 'ACTIVE' },
  { accountType: 'BUSINESS', operatorCode: 'BT', operatorName: 'BSNL STV', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 3.0, retailerCommission: 2.00, companyCommission: 1.0, status: 'ACTIVE' },
  
  // DTH
  { accountType: 'BUSINESS', operatorCode: 'TP', operatorName: 'Tata Play', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 3.20, companyCommission: 0.8, status: 'ACTIVE' },
  { accountType: 'BUSINESS', operatorCode: 'DISH', operatorName: 'Dish TV', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 3.25, companyCommission: 0.75, status: 'ACTIVE' },
  { accountType: 'BUSINESS', operatorCode: 'SUN', operatorName: 'Sun Direct', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 3.25, companyCommission: 0.75, status: 'ACTIVE' },
  { accountType: 'BUSINESS', operatorCode: 'AIRDTH', operatorName: 'Airtel DTH', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 3.20, companyCommission: 0.8, status: 'ACTIVE' },
  
  // Electricity / BBPS
  { accountType: 'BUSINESS', operatorCode: 'BESCOM', operatorName: 'BESCOM Electricity', serviceType: 'electricity', commissionType: 'percentage', providerCommission: 0.8, retailerCommission: 0.40, companyCommission: 0.4, status: 'ACTIVE' },
  { accountType: 'BUSINESS', operatorCode: 'TSSPDCL', operatorName: 'TSSPDCL Electricity', serviceType: 'electricity', commissionType: 'percentage', providerCommission: 0.8, retailerCommission: 0.40, companyCommission: 0.4, status: 'ACTIVE' },
  { accountType: 'BUSINESS', operatorCode: 'TGSPDCL', operatorName: 'TGSPDCL Electricity', serviceType: 'electricity', commissionType: 'percentage', providerCommission: 0.8, retailerCommission: 0.40, companyCommission: 0.4, status: 'ACTIVE' },
  
  // Gas & FASTag
  { accountType: 'BUSINESS', operatorCode: 'IGAS', operatorName: 'Indane Gas', serviceType: 'gas', commissionType: 'percentage', providerCommission: 1.0, retailerCommission: 0.50, companyCommission: 0.5, status: 'ACTIVE' },
  { accountType: 'BUSINESS', operatorCode: 'PFAST', operatorName: 'Paytm FASTag', serviceType: 'fastag', commissionType: 'percentage', providerCommission: 0.6, retailerCommission: 0.30, companyCommission: 0.3, status: 'ACTIVE' },
];

// Default initial PERSONAL seed slabs
const defaultPersonalSeedCommissions = [
  // Mobile
  { accountType: 'PERSONAL', operatorCode: 'AT', operatorName: 'Airtel', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 2.0, retailerCommission: 0.40, personalCommission: 0.40, companyCommission: 1.6, status: 'ACTIVE' },
  { accountType: 'PERSONAL', operatorCode: 'JO', operatorName: 'Jio', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 1.5, retailerCommission: 0.30, personalCommission: 0.30, companyCommission: 1.2, status: 'ACTIVE' },
  { accountType: 'PERSONAL', operatorCode: 'VI', operatorName: 'Vi', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 3.5, retailerCommission: 0.40, personalCommission: 0.40, companyCommission: 3.1, status: 'ACTIVE' },
  { accountType: 'PERSONAL', operatorCode: 'BR', operatorName: 'BSNL', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 3.0, retailerCommission: 0.50, personalCommission: 0.50, companyCommission: 2.5, status: 'ACTIVE' },
  { accountType: 'PERSONAL', operatorCode: 'BT', operatorName: 'BSNL STV', serviceType: 'mobile', commissionType: 'percentage', providerCommission: 3.0, retailerCommission: 0.50, personalCommission: 0.50, companyCommission: 2.5, status: 'ACTIVE' },
  
  // DTH
  { accountType: 'PERSONAL', operatorCode: 'TP', operatorName: 'Tata Play', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 0.80, personalCommission: 0.80, companyCommission: 3.2, status: 'ACTIVE' },
  { accountType: 'PERSONAL', operatorCode: 'DISH', operatorName: 'Dish TV', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 0.80, personalCommission: 0.80, companyCommission: 3.2, status: 'ACTIVE' },
  { accountType: 'PERSONAL', operatorCode: 'SUN', operatorName: 'Sun Direct', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 0.80, personalCommission: 0.80, companyCommission: 3.2, status: 'ACTIVE' },
  { accountType: 'PERSONAL', operatorCode: 'AIRDTH', operatorName: 'Airtel DTH', serviceType: 'dth', commissionType: 'percentage', providerCommission: 4.0, retailerCommission: 0.80, personalCommission: 0.80, companyCommission: 3.2, status: 'ACTIVE' },
  
  // Electricity / BBPS
  { accountType: 'PERSONAL', operatorCode: 'BESCOM', operatorName: 'BESCOM Electricity', serviceType: 'electricity', commissionType: 'percentage', providerCommission: 0.8, retailerCommission: 0.20, personalCommission: 0.20, companyCommission: 0.6, status: 'ACTIVE' },
  { accountType: 'PERSONAL', operatorCode: 'TSSPDCL', operatorName: 'TSSPDCL Electricity', serviceType: 'electricity', commissionType: 'percentage', providerCommission: 0.8, retailerCommission: 0.20, personalCommission: 0.20, companyCommission: 0.6, status: 'ACTIVE' },
  { accountType: 'PERSONAL', operatorCode: 'TGSPDCL', operatorName: 'TGSPDCL Electricity', serviceType: 'electricity', commissionType: 'percentage', providerCommission: 0.8, retailerCommission: 0.20, personalCommission: 0.20, companyCommission: 0.6, status: 'ACTIVE' },
  
  // Gas & FASTag
  { accountType: 'PERSONAL', operatorCode: 'IGAS', operatorName: 'Indane Gas', serviceType: 'gas', commissionType: 'percentage', providerCommission: 1.0, retailerCommission: 0.25, personalCommission: 0.25, companyCommission: 0.75, status: 'ACTIVE' },
  { accountType: 'PERSONAL', operatorCode: 'PFAST', operatorName: 'Paytm FASTag', serviceType: 'fastag', commissionType: 'percentage', providerCommission: 0.6, retailerCommission: 0.15, personalCommission: 0.15, companyCommission: 0.45, status: 'ACTIVE' },
];

/**
 * Safe Migration Helper: Clean up duplicate OperatorCommission records
 */
async function cleanupDuplicateOperatorCommissions() {
  try {
    if (mongoose.connection.readyState !== 1) return;

    const allDocs = await OperatorCommission.find({}).sort({ updatedAt: -1, createdAt: -1 }).lean();
    const seen = new Set();
    const idsToDelete = [];

    for (const doc of allDocs) {
      const accountType = (doc.accountType || 'PERSONAL').toUpperCase().trim();
      const serviceType = (doc.serviceType || 'mobile').toLowerCase().trim();
      const rawCode = (doc.operatorCode || '').toUpperCase().trim();
      const rawName = (doc.operatorName || '').toLowerCase().replace(/[^a-z0-9]/g, '');

      // Canonical operator code mapping for identical operators (e.g. A vs AT for Airtel Mobile)
      let canonicalCode = rawCode;
      if (serviceType === 'mobile') {
        if (['A', 'AT', 'AIRTEL'].includes(rawCode) || rawName === 'airtel') {
          canonicalCode = 'AT';
        } else if (['RC', 'JO', 'JIO'].includes(rawCode) || rawName === 'jio') {
          canonicalCode = 'JO';
        } else if (['V', 'VI', 'VODAFONE', 'IDEA'].includes(rawCode) || rawName === 'vi' || rawName === 'vodafone') {
          canonicalCode = 'VI';
        }
      } else if (serviceType === 'dth') {
        if (['AIRDTH', 'ATV', 'DA'].includes(rawCode) || rawName === 'airteldth') {
          canonicalCode = 'AIRDTH';
        }
      }

      const compositeKey = `${accountType}_${serviceType}_${canonicalCode}`;

      if (seen.has(compositeKey)) {
        console.log(`[CommissionMigration] Marking duplicate record for deletion: ID ${doc._id} (${compositeKey}) - ${doc.operatorName} (${doc.operatorCode})`);
        idsToDelete.push(doc._id);
      } else {
        seen.add(compositeKey);
        if (rawCode !== canonicalCode) {
          await OperatorCommission.updateOne(
            { _id: doc._id },
            { $set: { operatorCode: canonicalCode, operatorName: canonicalCode === 'AT' ? 'Airtel' : doc.operatorName } }
          );
        }
      }
    }

    if (idsToDelete.length > 0) {
      console.log(`[CommissionMigration] Safely deleting ${idsToDelete.length} duplicate OperatorCommission records...`);
      await OperatorCommission.deleteMany({ _id: { $in: idsToDelete } });
      console.log('[CommissionMigration] Duplicate cleanup completed successfully.');
    }
  } catch (err) {
    console.error('[CommissionMigration Error]:', err.message);
  }
}

/**
 * Migration & Seeding Helper
 */
async function seedInitialCommissionsIfEmpty() {
  try {
    if (mongoose.connection.readyState !== 1) return;

    // Drop obsolete single-field or old compound indexes if present
    try {
      const collection = OperatorCommission.collection;
      const indexes = await collection.indexes();
      for (const idx of indexes) {
        if (idx.name === 'operatorCode_1' || idx.name === 'accountType_1_operatorCode_1') {
          console.log(`[CommissionEngine] Dropping obsolete index ${idx.name}...`);
          await collection.dropIndex(idx.name);
        }
      }
    } catch (e) {
      // Ignore index drop error if already dropped
    }

    // Ensure any existing document missing accountType gets 'BUSINESS'
    await OperatorCommission.updateMany(
      { $or: [{ accountType: { $exists: false } }, { accountType: null }] },
      { $set: { accountType: 'BUSINESS' } }
    );

    // Clean up duplicate records first
    await cleanupDuplicateOperatorCommissions();

    // Check count of BUSINESS and PERSONAL slabs
    const businessCount = await OperatorCommission.countDocuments({ accountType: 'BUSINESS' });
    if (businessCount === 0) {
      console.log('[CommissionEngine] Seeding initial BUSINESS operator commissions...');
      await OperatorCommission.insertMany(defaultBusinessSeedCommissions);
    }

    const personalCount = await OperatorCommission.countDocuments({ accountType: 'PERSONAL' });
    if (personalCount === 0) {
      console.log('[CommissionEngine] Seeding initial PERSONAL operator commissions...');
      await OperatorCommission.insertMany(defaultPersonalSeedCommissions);
    }
  } catch (err) {
    console.error('[CommissionEngine] Error during commission seeding/migration:', err.message);
  }
}

// Automatically seed and clean up on module load
seedInitialCommissionsIfEmpty();

/**
 * @desc Get active commission slabs directly from MongoDB (supports accountType filter)
 * @route GET /api/commission/slabs or GET /api/commission
 */
const getActiveSlabs = async (req, res, next) => {
  try {
    await seedInitialCommissionsIfEmpty();

    // Prioritize authenticated user's accountType for end users
    let accountType = (req.user && req.user.accountType) ? req.user.accountType : (req.query.accountType || req.body.accountType);

    const query = { status: 'ACTIVE' };
    if (accountType) {
      const norm = String(accountType).trim().toUpperCase();
      query.accountType = norm === 'PERSONAL' ? 'PERSONAL' : 'BUSINESS';
    }

    const dbCommissions = await OperatorCommission.find(query)
      .sort({ accountType: 1, serviceType: 1, operatorName: 1 })
      .lean();

    // Deduplicate & normalize slabs per service category and operator identifier
    const uniqueMap = new Map();
    for (const item of dbCommissions) {
      const service = (item.serviceType || 'mobile').toLowerCase().trim();
      const code = (item.operatorCode || '').toUpperCase().trim();
      const name = (item.operatorName || '').trim();
      const normName = name.toLowerCase().replace(/[^a-z0-9]/g, '');

      const opKey = code || normName;
      const compositeKey = `${service}_${opKey}`;

      const isPersonal = (item.accountType || 'BUSINESS') === 'PERSONAL';
      const effectiveValue = isPersonal
        ? (item.personalCommission ?? item.retailerCommission ?? 0)
        : (item.retailerCommission ?? 0);

      const formatted = {
        id: item._id.toString(),
        accountType: item.accountType || 'BUSINESS',
        operatorCode: code,
        operatorName: name,
        serviceType: service,
        commissionType: item.commissionType || 'percentage',
        commissionValue: Number(effectiveValue),
        retailerCommission: item.retailerCommission,
        providerCommission: item.providerCommission,
        personalCommission: item.personalCommission ?? item.retailerCommission,
        companyCommission: item.companyCommission,
        effectiveFrom: item.createdAt ? new Date(item.createdAt).toISOString() : new Date().toISOString(),
        updatedAt: item.updatedAt ? new Date(item.updatedAt).toISOString() : new Date().toISOString(),
      };

      if (!uniqueMap.has(compositeKey)) {
        uniqueMap.set(compositeKey, formatted);
      } else {
        const existing = uniqueMap.get(compositeKey);
        if (formatted.commissionValue > existing.commissionValue) {
          uniqueMap.set(compositeKey, formatted);
        }
      }
    }

    const formattedSlabs = Array.from(uniqueMap.values());

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
 * @desc Update or Create operator commission in MongoDB (Admin Dashboard API)
 * @route PUT /api/commission/update or POST /api/commission/create
 */
const updateCommission = async (req, res, next) => {
  try {
    const {
      accountType,
      operatorCode,
      operatorName,
      retailerCommission,
      providerCommission,
      personalCommission,
      companyCommission,
      status,
      serviceType,
    } = req.body;

    if (!accountType) {
      return res.status(400).json({
        success: false,
        message: 'accountType is required and must be either PERSONAL or BUSINESS',
      });
    }

    const normAccountType = String(accountType).trim().toUpperCase();
    if (!['PERSONAL', 'BUSINESS'].includes(normAccountType)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid accountType. Allowed values: PERSONAL, BUSINESS',
      });
    }

    if (!operatorCode) {
      return res.status(400).json({
        success: false,
        message: 'operatorCode is required',
      });
    }

    const cleanOpCode = String(operatorCode).trim().toUpperCase();

    const updateFields = {
      accountType: normAccountType,
      operatorCode: cleanOpCode,
    };

    if (operatorName !== undefined) updateFields.operatorName = String(operatorName).trim();
    if (retailerCommission !== undefined) updateFields.retailerCommission = Number(retailerCommission);
    if (providerCommission !== undefined) updateFields.providerCommission = Number(providerCommission);
    if (personalCommission !== undefined) updateFields.personalCommission = Number(personalCommission);
    if (companyCommission !== undefined) updateFields.companyCommission = Number(companyCommission);
    if (status !== undefined) updateFields.status = String(status).toUpperCase();
    const cleanServiceType = serviceType ? String(serviceType).toLowerCase().trim() : 'mobile';
    updateFields.serviceType = cleanServiceType;

    const updated = await OperatorCommission.findOneAndUpdate(
      { accountType: normAccountType, serviceType: cleanServiceType, operatorCode: cleanOpCode },
      { $set: updateFields },
      { new: true, upsert: true }
    ).lean();

    console.log(`[CommissionEngine] Updated ${normAccountType} commission for ${updated.operatorName} (${updated.operatorCode}) -> Retailer: ${updated.retailerCommission}%`);

    return res.status(200).json({
      success: true,
      message: `Commission updated successfully for ${updated.operatorName} (${normAccountType})`,
      data: {
        id: updated._id.toString(),
        accountType: updated.accountType,
        operatorCode: updated.operatorCode,
        operatorName: updated.operatorName,
        serviceType: updated.serviceType,
        commissionType: updated.commissionType,
        commissionValue: updated.retailerCommission,
        providerCommission: updated.providerCommission,
        personalCommission: updated.personalCommission,
        companyCommission: updated.companyCommission,
        status: updated.status,
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

const getCommissionForOperator = async (operatorIdentifier, accountType = 'BUSINESS') => {
  if (!operatorIdentifier) return null;
  const targetAccountType = String(accountType).trim().toUpperCase() === 'PERSONAL' ? 'PERSONAL' : 'BUSINESS';
  const aliases = getOperatorCodeAliases(operatorIdentifier);
  const cleanName = String(operatorIdentifier).trim().toLowerCase();

  if (mongoose.connection.readyState !== 1) {
    const seedPool = targetAccountType === 'PERSONAL' ? defaultPersonalSeedCommissions : defaultBusinessSeedCommissions;
    const found = seedPool.find(s => 
      s.status === 'ACTIVE' && 
      (aliases.includes(s.operatorCode.toUpperCase()) || s.operatorName.toLowerCase().includes(cleanName))
    );
    return found || null;
  }

  let record = await OperatorCommission.findOne({
    accountType: targetAccountType,
    status: 'ACTIVE',
    $or: [
      { operatorCode: { $in: aliases } },
      { operatorName: { $regex: new RegExp(`^${cleanName}$`, 'i') } },
      { operatorName: { $regex: new RegExp(cleanName, 'i') } },
    ],
  }).lean();

  return record;
};

const getCommissionForOperatorAndService = async (serviceType = 'mobile', operatorIdentifier = '', accountType = 'BUSINESS') => {
  if (!operatorIdentifier) return null;
  const targetAccountType = String(accountType).trim().toUpperCase() === 'PERSONAL' ? 'PERSONAL' : 'BUSINESS';
  const sType = String(serviceType).toLowerCase().trim();
  const aliases = getOperatorCodeAliases(operatorIdentifier);
  const cleanName = String(operatorIdentifier).trim().toLowerCase();

  if (mongoose.connection.readyState !== 1) {
    const seedPool = targetAccountType === 'PERSONAL' ? defaultPersonalSeedCommissions : defaultBusinessSeedCommissions;
    const found = seedPool.find(s => 
      s.status === 'ACTIVE' && 
      (!sType || s.serviceType === sType) &&
      (aliases.includes(s.operatorCode.toUpperCase()) || s.operatorName.toLowerCase().includes(cleanName))
    );
    return found || null;
  }

  let record = await OperatorCommission.findOne({
    accountType: targetAccountType,
    status: 'ACTIVE',
    serviceType: sType,
    $or: [
      { operatorCode: { $in: aliases } },
      { operatorName: { $regex: new RegExp(`^${cleanName}$`, 'i') } },
      { operatorName: { $regex: new RegExp(cleanName, 'i') } },
    ],
  }).lean();

  if (!record) {
    record = await OperatorCommission.findOne({
      accountType: targetAccountType,
      status: 'ACTIVE',
      $or: [
        { operatorCode: { $in: aliases } },
        { operatorName: { $regex: new RegExp(`^${cleanName}$`, 'i') } },
        { operatorName: { $regex: new RegExp(cleanName, 'i') } },
      ],
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
  seedInitialCommissionsIfEmpty,
};
