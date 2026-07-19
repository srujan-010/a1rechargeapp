// lib/core/constants/api_endpoints.dart
// All REST API endpoint paths as constants.
// IMPORTANT: These must match the backend route definitions exactly (field names, casing).
// Verified against backend/src/routes/ during Phase 13.

abstract final class ApiEndpoints {
  // ─── Authentication ───────────────────────────────────────────────
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String setupMpin = '/auth/setup-mpin';
  static const String verifyMpin = '/auth/verify-mpin';
  static const String changeMpin = '/auth/change-mpin';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';
  static const String sessionCheck = '/auth/me';

  // ─── Wallet ───────────────────────────────────────────────────────
  static const String walletBalance = '/wallet/balance';
  static const String walletStatement = '/wallet/statement';
  static const String walletTopupRequest = '/wallet/topup-request';
  static const String walletTopupStatus = '/wallet/topup-request/:requestId/status';
  static const String commissionHistory = '/wallet/commission-history';
  static const String earningsSummary = '/wallet/earnings-summary';

  // ─── Mobile Recharge ─────────────────────────────────────────────
  static const String detectOperator = '/recharge/detect-operator';
  static const String rechargeOperators = '/recharge/operators';
  static const String rechargePlans = '/recharge/plans';
  static const String initiateRecharge = '/recharge/initiate';
  static const String rechargeStatus = '/recharge/status/:txnId';

  // ─── DTH ─────────────────────────────────────────────────────────
  static const String dthOperators = '/dth/operators';
  static const String dthPlans = '/dth/plans';
  static const String initiateDth = '/dth/initiate';

  // ─── BBPS ────────────────────────────────────────────────────────
  static const String bbpsCategories = '/bbps/categories';
  static const String bbpsBillers = '/bbps/billers/:category';
  static const String bbpsFetchBill = '/bbps/fetch-bill';
  static const String bbpsPayBill = '/bbps/pay';

  // ─── AEPS ────────────────────────────────────────────────────────
  static const String aepsBanks = '/aeps/banks';
  static const String aepsCashWithdrawal = '/aeps/cash-withdrawal';
  static const String aepsBalanceEnquiry = '/aeps/balance-enquiry';
  static const String aepsMiniStatement = '/aeps/mini-statement';
  static const String aepsAadhaarPay = '/aeps/aadhaar-pay';

  // ─── DMT ─────────────────────────────────────────────────────────
  static const String dmtBeneficiaries = '/dmt/beneficiaries';
  static const String dmtAddBeneficiary = '/dmt/beneficiaries/add';
  static const String dmtDeleteBeneficiary = '/dmt/beneficiaries/:id';
  static const String dmtVerifyAccount = '/dmt/verify-account';
  static const String dmtTransfer = '/dmt/transfer';
  static const String dmtTransferHistory = '/dmt/history';
  static const String ifscLookup = '/dmt/ifsc/:ifsc';

  // ─── Insurance ───────────────────────────────────────────────────
  static const String insuranceCategories = '/insurance/categories';
  static const String insuranceProducts = '/insurance/products';
  static const String insurancePremiumCalc = '/insurance/calculate-premium';
  static const String insuranceBuy = '/insurance/buy';
  static const String insurancePolicies = '/insurance/policies';

  // ─── Loan ────────────────────────────────────────────────────────
  static const String loanTypes = '/loan/types';
  static const String loanEligibility = '/loan/eligibility-check';
  static const String loanApply = '/loan/apply';
  static const String loanApplications = '/loan/applications';
  static const String loanApplicationDetail = '/loan/applications/:id';

  // ─── Transaction History ─────────────────────────────────────────
  static const String transactions = '/transactions';
  static const String transactionDetail = '/transactions/:txnId';

  // ─── Notifications ───────────────────────────────────────────────
  static const String notifications = '/notifications';
  static const String markNotificationRead = '/notifications/:id/read';
  static const String markAllNotificationsRead = '/notifications/read-all';
  static const String fcmTokenUpdate = '/notifications/fcm-token';

  // ─── Profile ─────────────────────────────────────────────────────
  static const String retailerProfile = '/profile';
  static const String updateProfile = '/profile';
  static const String bankDetails = '/profile/bank';
  static const String kycStatus = '/profile/kyc/status';
  static const String kycUpload = '/profile/kyc/upload';
  static const String commissionSlab = '/profile/commission-slab';
  static const String biometricSettings = '/profile/biometric-settings';

  // ─── Dashboard ───────────────────────────────────────────────────
  static const String dashboardSummary = '/dashboard/summary';
  static const String offers = '/dashboard/offers';
  static const String recentTransactions = '/dashboard/recent-transactions';

  // ─── Support ─────────────────────────────────────────────────────
  static const String supportTickets = '/support/tickets';
  static const String createTicket = '/support/tickets';
  static const String ticketDetail = '/support/tickets/:id';
  static const String faqs = '/support/faqs';
  static const String knowledgeBase = '/support/kb';
  static const String kbArticle = '/support/kb/:articleId';

  // ─── Commission ───────────────────────────────────────────────────
  /// GET /commission/slabs — list all active commission slabs for this retailer.
  static const String commissionSlabs = '/commission/slabs';

  /// GET /commission/earned?from=ISO8601&to=ISO8601 — earned commission entries.
  static const String earnedCommission = '/commission/earned';

  // ─── App Config ───────────────────────────────────────────────────
  static const String appSettings = '/settings/app';
}
