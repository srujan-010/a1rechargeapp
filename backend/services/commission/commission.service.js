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

      // STRICT ACCOUNT TYPE SEPARATION (Task 4 & Task 13):
      // If no active slab exists for targetAccountType, throw error. NEVER fall back to opposite accountType!
      if (!commissionRule) {
        console.log('\n====================================================');
        console.log('[COMMISSION CONFIG NOT FOUND]');
        console.log(`Lookup Parameters - accountType: ${targetAccountType}, operatorCode: ${operatorCode}, operatorName: ${operatorName}, serviceType: ${effectiveServiceType}`);
        console.log('====================================================\n');
        throw new Error(`No active commission slab configured for ${targetAccountType} account type.`);
      }

      const providerPercent = this._safeFloat(commissionRule.providerCommission, 0);
      const retailerPercent = this._safeFloat(commissionRule.retailerCommission ?? commissionRule.commissionValue, 0);
      const companyPercent = this._safeFloat(commissionRule.companyCommission, 0);

      const personalPercent = commissionRule.personalCommission != null
        ? this._safeFloat(commissionRule.personalCommission, 0)
        : (targetAccountType === 'PERSONAL' ? retailerPercent : 0);

      const providerAmount = this._safeFloat((safeAmount * providerPercent) / 100, 0);
      const retailerAmount = this._safeFloat((safeAmount * retailerPercent) / 100, 0);
      const companyAmount = this._safeFloat((safeAmount * companyPercent) / 100, 0);
      const personalDiscountAmount = this._safeFloat((safeAmount * personalPercent) / 100, 0);

      console.log('\n====================================================');
      console.log('[COMMISSION CONFIG FOUND]');
      console.log(`accountType: ${targetAccountType}`);
      console.log(`operator: ${commissionRule.operatorName} (${commissionRule.operatorCode})`);
      console.log(`serviceType: ${commissionRule.serviceType || effectiveServiceType}`);
      console.log(`planType: ${planType}`);
      console.log(`commissionRecordId: ${commissionRule._id}`);
      console.log(`providerCommissionPercent: ${providerPercent}`);
      console.log(`retailerCommissionPercent: ${retailerPercent}`);
      console.log(`personalCommissionPercent: ${personalPercent}`);
      console.log(`active: ${commissionRule.status}`);
      console.log('====================================================\n');

      return {
        accountType: targetAccountType,
        providerCommissionPercentage: providerPercent,
        providerCommissionAmount: providerAmount,
        retailerCommissionPercentage: retailerPercent,
        retailerCommissionAmount: retailerAmount,
        personalCommissionPercentage: personalPercent,
        personalDiscountAmount: personalDiscountAmount,
        companyProfitPercentage: companyPercent,
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
