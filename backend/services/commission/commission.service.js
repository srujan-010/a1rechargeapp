const OperatorCommission = require('../../models/OperatorCommission');

class CommissionService {
  /**
   * Calculate commissions for a given operator and amount
   */
  async calculateCommission(operatorCode, amount) {
    const commissionRule = await OperatorCommission.findOne({ operatorCode, status: 'ACTIVE' });

    if (!commissionRule) {
      // If no dynamic rule, default to 0 commission to be safe
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
