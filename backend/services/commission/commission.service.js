const OperatorCommission = require('../../models/OperatorCommission');
const ProviderOperator = require('../../models/ProviderOperator');
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
  async calculateCommission(operatorCode, amount, operatorName = '', serviceType = 'mobile') {
    const safeAmount = this._safeNum(amount, 0);

    try {
      const commissionRule = await OperatorCommission.findOne({ operatorCode, status: 'ACTIVE' });

      if (!commissionRule) {
        let resolvedOperatorName = operatorName;
        if (!resolvedOperatorName) {
          const providerOp = await ProviderOperator.findOne({ code: operatorCode });
          if (providerOp) {
            resolvedOperatorName = providerOp.name;
            serviceType = providerOp.type === 'dth' ? 'dth' : 'mobile';
          }
        }

        if (resolvedOperatorName) {
          const fallback = calculateCommissionFallback(serviceType, resolvedOperatorName, safeAmount * 100);
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
          };
        }

        return {
          providerCommissionPercentage: 0,
          providerCommissionAmount: 0,
          retailerCommissionPercentage: 0,
          retailerCommissionAmount: 0,
          companyProfitPercentage: 0,
          companyProfitAmount: 0,
        };
      }

      const providerPercent = this._safeFloat(commissionRule.providerCommission, 0);
      const retailerPercent = this._safeFloat(commissionRule.retailerCommission, 0);
      const companyPercent = this._safeFloat(commissionRule.companyCommission, 0);

      const providerAmount = this._safeFloat((safeAmount * providerPercent) / 100, 0);
      const retailerAmount = this._safeFloat((safeAmount * retailerPercent) / 100, 0);
      const companyAmount = this._safeFloat((safeAmount * companyPercent) / 100, 0);

      return {
        providerCommissionPercentage: providerPercent,
        providerCommissionAmount: providerAmount,
        retailerCommissionPercentage: retailerPercent,
        retailerCommissionAmount: retailerAmount,
        companyProfitPercentage: companyPercent,
        companyProfitAmount: companyAmount,
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
      };
    }
  }
}

module.exports = new CommissionService();
