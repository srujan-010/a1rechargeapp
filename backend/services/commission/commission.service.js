const OperatorCommission = require('../../models/OperatorCommission');
const ProviderOperator = require('../../models/ProviderOperator');
const { calculateCommission: calculateCommissionFallback } = require('../../utils/commissionEngine');

class CommissionService {
  /**
   * Calculate commissions for a given operator and amount
   */
  async calculateCommission(operatorCode, amount, operatorName = '', serviceType = 'mobile') {
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
        const fallback = calculateCommissionFallback(serviceType, resolvedOperatorName, amount * 100);
        return {
          providerCommissionPercentage: fallback.commissionPercentage,
          providerCommissionAmount: fallback.commissionAmountPaise / 100,
          retailerCommissionPercentage: fallback.commissionPercentage,
          retailerCommissionAmount: fallback.commissionAmountPaise / 100,
          companyProfitPercentage: 0,
          companyProfitAmount: 0,
        };
      }

      // If no dynamic rule and no fallback possible, default to 0 commission to be safe
      return {
        providerCommissionPercentage: 0,
        providerCommissionAmount: 0,
        retailerCommissionPercentage: 0,
        retailerCommissionAmount: 0,
        companyProfitPercentage: 0,
        companyProfitAmount: 0,
      };
    }

    const providerAmount = parseFloat((amount * (commissionRule.providerCommission / 100)).toFixed(2));
    const retailerAmount = parseFloat((amount * (commissionRule.retailerCommission / 100)).toFixed(2));
    const companyAmount = parseFloat((amount * (commissionRule.companyCommission / 100)).toFixed(2));

    return {
      providerCommissionPercentage: commissionRule.providerCommission,
      providerCommissionAmount: providerAmount,
      retailerCommissionPercentage: commissionRule.retailerCommission,
      retailerCommissionAmount: retailerAmount,
      companyProfitPercentage: commissionRule.companyCommission,
      companyProfitAmount: companyAmount,
    };
  }
}

module.exports = new CommissionService();
