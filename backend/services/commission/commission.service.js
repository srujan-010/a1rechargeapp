const OperatorCommission = require('../../models/OperatorCommission');
const ProviderOperator = require('../../models/ProviderOperator');
const { getCommissionForOperatorAndService, getOperatorCodeAliases } = require('../../controllers/commissionController');

class CommissionService {
  /**
   * Helper to safely format number to 2 decimals without NaN
   */
  _safeNum(val, defaultVal = 0) {
    const num = Number(val);
    return isNaN(num) || !isFinite(num) ? defaultVal : num;
  }

  _safeFloat(val, defaultVal = 0) {
    const num = this._safeNum(val, defaultVal);
    return Number(num.toFixed(2));
  }

  /**
   * Calculate commissions for a given operator, amount, and user accountType
   */
  async calculateCommission(operatorCode, amount, operatorName = '', serviceType = 'mobile', contextOptions = {}) {
    const safeAmount = this._safeNum(amount, 0);

    const {
      orderId = 'N/A',
      retailerId = 'N/A',
      operatorId = 'N/A',
      planType = 'N/A',
      accountType = 'BUSINESS',
    } = contextOptions;

    const rawAccountType = String(accountType || 'BUSINESS').trim().toUpperCase();
    const targetAccountType = rawAccountType === 'PERSONAL' ? 'PERSONAL' : 'BUSINESS';
    const effectiveServiceType = serviceType || 'mobile';

    console.log('\n====================================================');
    console.log('[COMMISSION LOOKUP]');
    console.log(`orderId: ${orderId}`);
    console.log(`retailerId: ${retailerId}`);
    console.log(`accountType: ${targetAccountType}`);
    console.log(`operator: ${operatorName || 'N/A'}`);
    console.log(`operatorId: ${operatorId}`);
    console.log(`providerOperatorCode: ${operatorCode || 'N/A'}`);
    console.log(`serviceType: ${effectiveServiceType}`);
    console.log(`planType: ${planType}`);
    console.log(`rechargeAmount: ${safeAmount}`);
    console.log('====================================================\n');

    try {
      const cleanCode = String(operatorCode || '').trim().toUpperCase();
      const cleanName = String(operatorName || '').trim();

      // 1. Primary Lookup: Exact accountType + operatorCode
      let commissionRule = null;
      if (cleanCode) {
        commissionRule = await OperatorCommission.findOne({
          accountType: targetAccountType,
          operatorCode: cleanCode,
          status: 'ACTIVE',
        }).lean();
      }

      // 2. Secondary Lookup: Alias / Name match for targetAccountType
      if (!commissionRule) {
        const aliases = getOperatorCodeAliases(operatorCode || operatorName);
        commissionRule = await OperatorCommission.findOne({
          accountType: targetAccountType,
          status: 'ACTIVE',
          $or: [
            { operatorCode: { $in: aliases } },
            ...(cleanName ? [{ operatorName: { $regex: new RegExp(`^${cleanName}$`, 'i') } }] : []),
          ],
        }).lean();
      }

      // If empty DB, auto-seed default commissions and retry
      if (!commissionRule) {
        const count = await OperatorCommission.countDocuments({ accountType: targetAccountType }).catch(() => 0);
        if (count === 0) {
          const { seedInitialCommissionsIfEmpty } = require('../../controllers/commissionController');
          await seedInitialCommissionsIfEmpty().catch(() => {});
          if (cleanCode) {
            commissionRule = await OperatorCommission.findOne({
              accountType: targetAccountType,
              operatorCode: cleanCode,
              status: 'ACTIVE',
            }).lean();
          }
          if (!commissionRule) {
            const aliases = getOperatorCodeAliases(operatorCode || operatorName);
            commissionRule = await OperatorCommission.findOne({
              accountType: targetAccountType,
              status: 'ACTIVE',
              $or: [
                { operatorCode: { $in: aliases } },
                ...(cleanName ? [{ operatorName: { $regex: new RegExp(`^${cleanName}$`, 'i') } }] : []),
              ],
            }).lean();
          }
        }
      }

      // 3. Tertiary Lookup: Helper by serviceType + accountType
      if (!commissionRule && (effectiveServiceType || operatorName || operatorCode)) {
        commissionRule = await getCommissionForOperatorAndService(effectiveServiceType, operatorCode || operatorName, targetAccountType);
      }

      // STRICT ACCOUNT TYPE SEPARATION & DETERMINISTIC SLAB REQUIREMENT:
      // If no active slab exists for targetAccountType, throw COMMISSION_CONFIGURATION_NOT_FOUND error.
      // NEVER use hardcoded fallback percentages or select wrong accountType!
      if (!commissionRule || commissionRule.status !== 'ACTIVE') {
        console.log('\n====================================================');
        console.log('[COMMISSION CONFIG NOT FOUND]');
        console.log(`Lookup Parameters - accountType: ${targetAccountType}, operatorCode: ${cleanCode}, operatorName: ${cleanName}, serviceType: ${effectiveServiceType}`);
        console.log('====================================================\n');
        const err = new Error(`COMMISSION_CONFIGURATION_NOT_FOUND: No active commission slab configured for ${targetAccountType} account type and operator ${cleanCode || cleanName}.`);
        err.code = 'COMMISSION_CONFIGURATION_NOT_FOUND';
        throw err;
      }

      const grossAmountPaise = Math.round(safeAmount * 100);
      if (!Number.isSafeInteger(grossAmountPaise) || grossAmountPaise <= 0) {
        throw new Error(`[FINANCIAL INTEGRITY ERROR] Invalid grossAmountPaise: ${grossAmountPaise}`);
      }

      const providerPercent = this._safeFloat(commissionRule.providerCommission, 0);
      const retailerPercent = this._safeFloat(commissionRule.retailerCommission ?? commissionRule.commissionValue, 0);
      const companyPercent = this._safeFloat(commissionRule.companyCommission, 0);

      const personalPercent = commissionRule.personalCommission != null
        ? this._safeFloat(commissionRule.personalCommission, 0)
        : (targetAccountType === 'PERSONAL' ? retailerPercent : 0);

      // Deterministic Integer Paise arithmetic
      const retailerCommissionAmountPaise = Math.round((grossAmountPaise * retailerPercent * 100) / 10000);
      const providerCommissionAmountPaise = Math.round((grossAmountPaise * providerPercent * 100) / 10000);
      const companyProfitAmountPaise = Math.round((grossAmountPaise * companyPercent * 100) / 10000);
      const personalDiscountAmountPaise = Math.round((grossAmountPaise * personalPercent * 100) / 10000);

      const netPayablePaise = grossAmountPaise - retailerCommissionAmountPaise;

      // FINANCIAL SAFETY ASSERTIONS
      if (!Number.isSafeInteger(retailerCommissionAmountPaise) || retailerCommissionAmountPaise < 0 || retailerCommissionAmountPaise > grossAmountPaise) {
        throw new Error(`[FINANCIAL INTEGRITY ERROR] Invalid retailerCommissionAmountPaise: ${retailerCommissionAmountPaise}`);
      }
      if (!Number.isSafeInteger(netPayablePaise) || netPayablePaise < 0) {
        throw new Error(`[FINANCIAL INTEGRITY ERROR] Invalid netPayablePaise: ${netPayablePaise}`);
      }
      if (grossAmountPaise !== retailerCommissionAmountPaise + netPayablePaise) {
        throw new Error(`[FINANCIAL INVARIANT ERROR] Equation failed: gross (${grossAmountPaise}) !== commission (${retailerCommissionAmountPaise}) + netPayable (${netPayablePaise})`);
      }

      const providerAmount = Number((providerCommissionAmountPaise / 100).toFixed(2));
      const retailerAmount = Number((retailerCommissionAmountPaise / 100).toFixed(2));
      const companyAmount = Number((companyProfitAmountPaise / 100).toFixed(2));
      const personalDiscountAmount = Number((personalDiscountAmountPaise / 100).toFixed(2));

      console.log('\n====================================================');
      console.log('[COMMISSION CONFIG FOUND & CALCULATED]');
      console.log(`accountType: ${targetAccountType}`);
      console.log(`operator: ${commissionRule.operatorName} (${commissionRule.operatorCode})`);
      console.log(`serviceType: ${commissionRule.serviceType || effectiveServiceType}`);
      console.log(`planType: ${planType}`);
      console.log(`commissionRecordId: ${commissionRule._id}`);
      console.log(`grossAmountPaise: ${grossAmountPaise}`);
      console.log(`retailerCommissionPercentage: ${retailerPercent}%`);
      console.log(`retailerCommissionAmountPaise: ${retailerCommissionAmountPaise}`);
      console.log(`netPayablePaise: ${netPayablePaise}`);
      console.log(`active: ${commissionRule.status}`);
      console.log('====================================================\n');

      return {
        accountType: targetAccountType,
        grossAmountPaise,
        netPayablePaise,
        providerCommissionPercentage: providerPercent,
        providerCommissionAmountPaise,
        providerCommissionAmount: providerAmount,
        retailerCommissionPercentage: retailerPercent,
        retailerCommissionAmountPaise,
        retailerCommissionAmount: retailerAmount,
        personalCommissionPercentage: personalPercent,
        personalDiscountAmountPaise,
        personalDiscountAmount: personalDiscountAmount,
        companyProfitPercentage: companyPercent,
        companyProfitAmountPaise,
        companyProfitAmount: companyAmount,
        commissionRecordId: String(commissionRule._id),
      };
    } catch (error) {
      console.error(`Commission calculation failed: ${error.message}`);
      throw error;
    }
  }
}

module.exports = new CommissionService();
