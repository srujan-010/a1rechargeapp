/**
 * Wallet Funding Mode Configuration
 * Modes:
 * - 'ADMIN_ONLY': Only admin manual credits allowed. Retailer self-service top-up disabled.
 * - 'RAZORPAY' or 'PAYMENT_GATEWAY': Razorpay Checkout enabled for retailer self-service topup.
 * - 'BOTH': Both admin credit and Razorpay self-service topup enabled.
 */

const getWalletFundingMode = () => {
  const mode = (process.env.WALLET_FUNDING_MODE || 'RAZORPAY').toUpperCase();
  if (['ADMIN_ONLY', 'RAZORPAY', 'PAYMENT_GATEWAY', 'BOTH'].includes(mode)) {
    return mode;
  }
  return 'RAZORPAY';
};

const isPaymentGatewayEnabled = () => {
  const mode = getWalletFundingMode();
  return mode === 'RAZORPAY' || mode === 'PAYMENT_GATEWAY' || mode === 'BOTH';
};

const isRazorpayEnabled = () => {
  return isPaymentGatewayEnabled();
};

const isAdminCreditEnabled = () => {
  const mode = getWalletFundingMode();
  return mode === 'ADMIN_ONLY' || mode === 'BOTH';
};

const getRazorpayKeyId = () => {
  return process.env.RAZORPAY_KEY_ID || 'rzp_live_TKPje1gjpvHTve';
};

module.exports = {
  getWalletFundingMode,
  isPaymentGatewayEnabled,
  isRazorpayEnabled,
  isAdminCreditEnabled,
  getRazorpayKeyId,
};
