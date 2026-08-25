const OperatorCommission = require('../../models/OperatorCommission');
const ProviderOperator = require('../../models/ProviderOperator');
const { getCommissionForOperatorAndService, getOperatorCodeAliases } = require('../../controllers/commissionController');
const { calculateCommission: calculateCommissionFallback } = require('../../utils/commissionEngine');

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
   * Calculate commissions for a given operator and amount
   */
  async calculateCommission(operatorCode, amount, operatorName = '', serviceType = 'mobile', contextOptions = {}) {
    const safeAmount = this._safeNum(amount, 0);

    const {
      orderId = 'N/A',
      retailerId = 'N/A',
      operatorId = 'N/A',
      planType = 'N/A',
    } = contextOptions;

    console.log('\n====================================================');
    console.log('[COMMISSION LOOKUP]');
    console.log(`orderId: ${orderId}`);
    console.log(`retailerId: ${retailerId}`);
    console.log(`operator: ${operatorName || 'N/A'}`);
    console.log(`operatorId: ${operatorId}`);
    console.log(`providerOperatorCode: ${operatorCode || 'N/A'}`);
    console.log(`serviceType: ${serviceType || 'mobile'}`);
    console.log(`planType: ${planType}`);
    console.log(`rechargeAmount: ${safeAmount}`);
    console.log('====================================================\n');

    try {
      const cleanCode = String(operatorCode || '').trim().toUpperCase();
      const cleanName = String(operatorName || '').trim();

      // Primary: Exact operatorCode match
      let commissionRule = null;
      if (cleanCode) {
        commissionRule = await OperatorCommission.findOne({ operatorCode: cleanCode, status: 'ACTIVE' }).lean();
      }

      // Secondary: Alias / Name regex match
      if (!commissionRule) {
        const aliases = getOperatorCodeAliases(operatorCode || operatorName);
        commissionRule = await OperatorCommission.findOne({
          status: 'ACTIVE',
          $or: [
            { operatorCode: { $in: aliases } },
            ...(cleanName ? [{ operatorName: { $regex: new RegExp(`^${cleanName}$`, 'i') } }] : [])
          ]
        }).lean();
      }

      if (!commissionRule && (serviceType || operatorName || operatorCode)) {
        commissionRule = await getCommissionForOperatorAndService(serviceType, operatorCode || operatorName);
      }

      if (commissionRule) {
        const providerPercent = this._safeFloat(commissionRule.providerCommission, 0);
        const retailerPercent = this._safeFloat(commissionRule.retailerCommission ?? commissionRule.commissionValue, 0);
        const companyPercent = this._safeFloat(commissionRule.companyCommission, 0);

        // Personal rate is explicitly set on operator commission, or defaults to (retailer - adjustment)
        const personalAdjustment = this._safeFloat(process.env.PERSONAL_COMMISSION_ADJUSTMENT, 0.20);
        const personalPercent = commissionRule.personalCommission != null
          ? this._safeFloat(commissionRule.personalCommission, 0)
          : this._safeFloat(Math.max(0, retailerPercent - personalAdjustment), 0);

        const providerAmount = this._safeFloat((safeAmount * providerPercent) / 100, 0);
        const retailerAmount = this._safeFloat((safeAmount * retailerPercent) / 100, 0);
        const companyAmount = this._safeFloat((safeAmount * companyPercent) / 100, 0);
        const personalDiscountAmount = this._safeFloat((safeAmount * personalPercent) / 100, 0);

        console.log('\n====================================================');
        console.log('[COMMISSION CONFIG FOUND]');
        console.log(`commissionRecordId: ${commissionRule._id}`);
        console.log(`operator: ${commissionRule.operatorName} (${commissionRule.operatorCode})`);
        console.log(`serviceType: ${commissionRule.serviceType}`);
        console.log(`providerCommissionPercent: ${providerPercent}`);
        console.log(`retailerCommissionPercent: ${retailerPercent}`);
        console.log(`personalCommissionPercent: ${personalPercent}`);
        console.log(`active: ${commissionRule.status}`);
        console.log('====================================================\n');

        return {
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
      }

      console.log('\n====================================================');
      console.log('[COMMISSION CONFIG NOT FOUND]');
      console.log(`Lookup Parameters - operatorCode: ${operatorCode}, operatorName: ${operatorName}, serviceType: ${serviceType}`);
      console.log('====================================================\n');

      let resolvedOperatorName = operatorName;
      if (!resolvedOperatorName) {
        const providerOp = await ProviderOperator.findOne({ code: operatorCode });
        if (providerOp) {
          resolvedOperatorName = providerOp.name;
          serviceType = providerOp.serviceType === 'DTH' ? 'dth' : 'mobile';
        }
      }

      if (resolvedOperatorName) {
        const fallback = await calculateCommissionFallback(serviceType, resolvedOperatorName, safeAmount * 100);
        const percent = this._safeFloat(fallback?.commissionPercentage, 0);
        const amountPaise = this._safeNum(fallback?.commissionAmountPaise, 0);
        const calcAmount = this._safeFloat(amountPaise / 100, 0);

        return {
          providerCommissionPercentage: percent,
          providerCommissionAmount: calcAmount,
          retailerCommissionPercentage: percent,
          retailerCommissionAmount: calcAmount,
          companyProfitPercentage: 0,
          companyProfitAmount: 0,
          commissionRecordId: null,
        };
      }

      return {
        providerCommissionPercentage: 0,
        providerCommissionAmount: 0,
        retailerCommissionPercentage: 0,
        retailerCommissionAmount: 0,
        companyProfitPercentage: 0,
        companyProfitAmount: 0,
        commissionRecordId: null,
      };
    } catch (err) {
      console.error('[CommissionService Error]:', err);
      return {
        providerCommissionPercentage: 0,
        providerCommissionAmount: 0,
        retailerCommissionPercentage: 0,
        retailerCommissionAmount: 0,
        companyProfitPercentage: 0,
        companyProfitAmount: 0,
        commissionRecordId: null,
      };
    }
  }
}

module.exports = new CommissionService();
