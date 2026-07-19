const { getCommissionForOperatorAndService } = require('../controllers/commissionController');

/**
 * Calculates the commission for a given service type and operator.
 *
 * @param {string} serviceType - The service type (e.g., 'mobile', 'dth', 'bbps').
 * @param {string} operatorName - The name of the operator (e.g., 'Tata Play').
 * @param {number} amountPaise - The recharge amount in paise.
 * @returns {Object} An object containing commissionPercentage, commissionAmountPaise, and walletDebitedAmountPaise.
 */
const calculateCommission = (serviceType, operatorName, amountPaise) => {
  const slab = getCommissionForOperatorAndService(serviceType, operatorName);
  let commissionAmountPaise = 0;
  let commissionPercentage = 0;

  if (slab) {
    if (slab.commissionType === 'percentage') {
      commissionPercentage = slab.commissionValue;
      commissionAmountPaise = Math.floor(amountPaise * slab.commissionValue / 100);
    } else {
      // If there are flat commissions, we can just return 0% and the flat amount
      commissionAmountPaise = Math.floor(slab.commissionValue * 100);
    }
  }

  return {
    commissionPercentage,
    commissionAmountPaise,
    walletDebitedAmountPaise: amountPaise - commissionAmountPaise
  };
};

module.exports = { calculateCommission };
