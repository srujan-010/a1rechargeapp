import '../constants/route_names.dart';
import 'logger.dart';

abstract final class RouteResolver {
  /// Resolves any raw route string (e.g., notification payload "personal-benefits", "personal-information", "ROUTE_WALLET")
  /// to a valid registered GoRouter path.
  /// If the route is unresolvable or unknown, safely falls back to Dashboard without producing "Route not found" errors.
  static String resolve(String? rawRoute, {String fallbackRoute = RouteNames.dashboard}) {
    if (rawRoute == null || rawRoute.trim().isEmpty) {
      return fallbackRoute;
    }

    final clean = rawRoute.trim();

    switch (clean) {
      // Personal Benefits / Savings
      case 'personal-benefits':
      case 'personalBenefits':
      case '/personal/benefits':
      case '/personal/savings':
      case 'personal-savings':
      case 'ROUTE_BENEFITS':
      case 'ROUTE_SAVINGS':
        return RouteNames.personalBenefits;

      // Personal Information
      case 'personal-info':
      case 'personalInfo':
      case 'personal-information':
      case 'personalInformation':
      case '/profile/personal-info':
      case '/profile/personal-information':
      case 'ROUTE_PERSONAL_INFO':
        return RouteNames.personalInfo;

      // Core Navigation
      case 'dashboard':
      case '/dashboard':
      case '/shell/dashboard':
      case 'ROUTE_DASHBOARD':
      case 'ROUTE_HOME':
        return RouteNames.dashboard;

      case 'wallet':
      case '/wallet':
      case '/shell/wallet':
      case 'ROUTE_WALLET':
        return RouteNames.wallet;

      case 'profile':
      case '/profile':
      case '/shell/profile':
      case 'ROUTE_PROFILE':
        return RouteNames.profileView;

      case 'history':
      case '/history':
      case 'all-transactions':
      case 'ROUTE_HISTORY':
      case 'ROUTE_TRANSACTIONS':
        return RouteNames.transactionHistory;

      // Profile & Settings Sub-routes
      case 'kyc':
      case '/profile/kyc':
      case 'ROUTE_KYC':
        return RouteNames.kyc;

      case 'bank':
      case '/profile/bank':
      case 'ROUTE_BANK':
        return RouteNames.bankDetails;

      case 'security-pin':
      case '/profile/security-pin':
      case 'ROUTE_SECURITY_PIN':
        return RouteNames.securityPin;

      case 'wallet-mpin':
      case '/profile/wallet-mpin':
      case 'ROUTE_WALLET_MPIN':
        return RouteNames.walletMpin;

      case 'biometric':
      case '/profile/biometric':
      case 'ROUTE_BIOMETRIC':
        return RouteNames.biometricSettings;

      case 'notifications':
      case '/notifications':
      case 'ROUTE_NOTIFICATIONS':
        return RouteNames.notifications;

      case 'support':
      case '/support':
      case 'ROUTE_SUPPORT':
      case 'ROUTE_HELP':
        return RouteNames.support;

      case 'privacy':
      case '/settings/privacy':
      case 'ROUTE_PRIVACY':
        return RouteNames.privacyPolicy;

      case 'terms':
      case '/settings/terms':
      case 'ROUTE_TERMS':
        return RouteNames.termsAndConditions;
    }

    if (clean.startsWith('/')) {
      return clean;
    }

    AppLogger.warning('Unknown notification route: $rawRoute. Safely resolving to Dashboard.', tag: 'RouteResolver');
    return fallbackRoute;
  }
}
