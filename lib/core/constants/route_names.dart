// lib/core/constants/route_names.dart
// Named route constants for Go Router.
// All navigation uses these constants — never pass route strings inline.

abstract final class RouteNames {
  // ─── Root ─────────────────────────────────────────────────────────
  static const String splash = '/';

  // ─── Authentication ───────────────────────────────────────────────
  static const String onboarding = '/auth/onboarding';
  static const String otpLogin = '/auth/otp-login';
  static const String mpinSetup = '/auth/mpin-setup';
  static const String biometricPrompt = '/auth/biometric';

  // ─── Shell (bottom nav) ───────────────────────────────────────────
  static const String shell = '/shell';
  static const String dashboard = '/shell/dashboard';
  static const String history = '/shell/history';
  static const String scan = '/shell/scan';
  static const String wallet = '/shell/wallet';
  static const String profile = '/shell/profile';

  // ─── Wallet sub-routes ────────────────────────────────────────────
  static const String walletStatement = '/shell/wallet/statement';
  static const String walletTopup = '/shell/wallet/topup';
  static const String walletTopupStatus = '/shell/wallet/topup/status';
  static const String commissionHistory = '/shell/wallet/commission';
  static const String earnings = '/shell/wallet/earnings';

  // ─── Mobile Recharge ─────────────────────────────────────────────
  static const String mobileRecharge = '/recharge/mobile';
  static const String rechargePlans = '/recharge/mobile/plans';
  static const String rechargeConfirm = '/recharge/mobile/confirm';
  static const String rechargeReceipt = '/recharge/receipt/:txnId';

  // ─── DTH ─────────────────────────────────────────────────────────
  static const String dthRecharge = '/recharge/dth';
  static const String dthPlans = '/recharge/dth/plans';
  static const String dthConfirm = '/recharge/dth/confirm';
  static const String dthReceipt = '/recharge/dth/receipt/:txnId';

  // ─── BBPS ────────────────────────────────────────────────────────
  static const String bbps = '/bbps';
  static const String bbpsStateSelection = '/bbps/states/:category';
  static const String bbpsBiller = '/bbps/biller/:category';
  static const String bbpsBillFetch = '/bbps/fetch/:billerId';
  static const String bbpsPayConfirm = '/bbps/pay/:billerId';

  // ─── AEPS ────────────────────────────────────────────────────────
  static const String aeps = '/aeps';
  static const String aepsCashWithdrawal = '/aeps/cash-withdrawal';
  static const String aepsBalanceEnquiry = '/aeps/balance-enquiry';
  static const String aepsMiniStatement = '/aeps/mini-statement';
  static const String aepsAadhaarPay = '/aeps/aadhaar-pay';
  static const String aepsBiometric = '/aeps/biometric';
  static const String aepsReceipt = '/aeps/receipt';

  // ─── DMT ─────────────────────────────────────────────────────────
  static const String dmt = '/dmt';
  static const String dmtAddBeneficiary = '/dmt/add-beneficiary';
  static const String dmtTransfer = '/dmt/transfer/:beneficiaryId';
  static const String dmtBeneficiaries = '/dmt/beneficiaries';
  static const String dmtReceipt = '/dmt/receipt';

  // ─── Insurance ───────────────────────────────────────────────────
  static const String insurance = '/insurance';
  static const String insuranceProduct = '/insurance/product/:productId';
  static const String insurancePremium = '/insurance/premium/:productId';

  // ─── Loan ────────────────────────────────────────────────────────
  static const String loan = '/loan';
  static const String loanEmi = '/loan/emi/:providerId';
  static const String loanTrack = '/loan/track/:applicationId';

  // ─── Transaction History ─────────────────────────────────────────
  static const String transactionHistory = '/history';
  static const String transactionDetail = '/history/detail/:txnId';

  // ─── Notifications ───────────────────────────────────────────────
  static const String notifications = '/notifications';
  // ─── Profile ─────────────────────────────────────────────────────
  static const String profileView = '/profile';
  static const String personalInfo = '/profile/personal-info';
  static const String kyc = '/profile/kyc';
  static const String bankDetails = '/profile/bank';
  static const String commissionSlab = '/profile/commission-slab';
  static const String changeMpin = '/profile/change-mpin';
  static const String biometricSettings = '/profile/biometric';

  // ─── Settings ────────────────────────────────────────────────────
  static const String settings = '/settings';
  static const String notificationSettings = '/settings/notifications';
  static const String securitySettings = '/settings/security';
  static const String privacyPolicy = '/settings/privacy';
  static const String termsAndConditions = '/settings/terms';
  static const String refundPolicy = '/settings/refund';
  static const String aboutApp = '/settings/about';
  // ─── Support ─────────────────────────────────────────────────────
  static const String support = '/support';

  // ─── Extension points (future modules) ───────────────────────────
  // Extension point: QR Payments — route reserved
  static const String qrPayment = '/qr-payment';
  // Extension point: UPI Collection — route reserved
  static const String upiCollection = '/upi-collection';
  // Extension point: FASTag — route reserved
  static const String fastag = '/fastag';
  // Extension point: Distributor Module — route reserved
  static const String distributor = '/distributor';
}
