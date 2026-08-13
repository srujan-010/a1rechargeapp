const { getCommissionForOperatorAndService } = require('../controllers/commissionController');

/**
 * Calculates the commission for a given service type and operator.
 *
 * @param {string} serviceType - The service type (e.g., 'mobile', 'dth', 'bbps').
 * @param {string} operatorName - The name of the operator (e.g., 'Tata Play').
 * @param {number} amountPaise - The recharge amount in paise.
 * @returns {Promise<Object>} An object containing commissionPercentage, commissionAmountPaise, and walletDebitedAmountPaise.
 */
const calculateCommission = async (serviceType, operatorName, amountPaise) => {
  const safeAmountPaise = Number.isFinite(Number(amountPaise)) ? Number(amountPaise) : 0;
  const slab = await getCommissionForOperatorAndService(serviceType, operatorName);

  let commissionAmountPaise = 0;
  let commissionPercentage = 0;

  if (slab) {
    const rawVal = Number(slab.commissionValue ?? slab.retailerCommission ?? 0);
    const safeVal = Number.isFinite(rawVal) ? rawVal : 0;

    if (slab.commissionType === 'percentage') {
      commissionPercentage = safeVal;
      commissionAmountPaise = Math.floor((safeAmountPaise * safeVal) / 100);
    } else {
      commissionAmountPaise = Math.floor(safeVal * 100);
    }
  }

  const safeCommissionPaise = Number.isFinite(commissionAmountPaise) ? commissionAmountPaise : 0;
  const safeCommissionPercentage = Number.isFinite(commissionPercentage) ? commissionPercentage : 0;

  return {
    commissionPercentage: safeCommissionPercentage,
    commissionAmountPaise: safeCommissionPaise,
    walletDebitedAmountPaise: safeAmountPaise - safeCommissionPaise,
  };
};

module.exports = { calculateCommission };
