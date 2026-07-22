// lib/routes/app_router.dart
// Go Router configuration with auth guard, named routes, typed parameters,
// and consistent page transitions (fade + slide, 200ms, easeOutCubic).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/auth_provider.dart';
import '../core/constants/route_names.dart';
import '../core/providers/core_providers.dart';

// Import screens (using placeholder references — implemented in Phases 2-12)
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/screens/registration_screen.dart';
import '../features/auth_msg91/screens/msg91_login_screen.dart';
import '../features/auth_msg91/screens/msg91_otp_screen.dart';
// import '../features/authentication/presentation/mpin_setup_screen.dart';
// import '../features/authentication/presentation/biometric_prompt_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/services/presentation/services_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/wallet/presentation/wallet_statement_screen.dart';
import '../features/wallet/presentation/wallet_topup_screen.dart';
import '../features/wallet/presentation/transaction_details_screen.dart';
import '../features/wallet/domain/models/wallet_transaction.dart';
import '../features/recharge/presentation/mobile_recharge_screen.dart';
import '../features/recharge/presentation/plan_selection_screen.dart';
import '../features/recharge/presentation/recharge_confirmation_screen.dart';
import '../features/recharge/presentation/recharge_receipt_screen.dart';
import '../features/recharge/domain/models/recharge_result.dart';
import '../features/dth/presentation/dth_recharge_screen.dart';
import '../features/dth/presentation/dth_plans_screen.dart';
import '../features/dth/presentation/dth_confirmation_screen.dart';
import '../features/dth/presentation/dth_receipt_screen.dart';
import '../features/bbps/presentation/bbps_screen.dart';
import '../features/bbps/presentation/bbps_state_selection_screen.dart';
import '../features/bbps/presentation/bbps_biller_screen.dart';
import '../features/bbps/presentation/bbps_fetch_screen.dart';
import '../features/bbps/presentation/bbps_pay_confirm_screen.dart';
import '../features/aeps/presentation/aeps_screen.dart';
import '../features/aeps/presentation/aeps_transaction_screen.dart';
import '../features/aeps/presentation/biometric_auth_screen.dart';
import '../features/aeps/presentation/aeps_receipt_screen.dart';
import '../features/aeps/domain/models/aeps_models.dart';
import '../features/dmt/presentation/dmt_screen.dart';
import '../features/dmt/presentation/dmt_beneficiaries_screen.dart';
import '../features/dmt/presentation/dmt_add_beneficiary_screen.dart';
import '../features/dmt/presentation/dmt_transfer_screen.dart';
import '../features/dmt/presentation/dmt_receipt_screen.dart';
import '../features/dmt/domain/models/dmt_models.dart';
import '../features/insurance/presentation/insurance_screen.dart';
import '../features/insurance/presentation/insurance_product_screen.dart';
import '../features/loan/presentation/loan_screen.dart';
import '../features/loan/presentation/loan_emi_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/support/presentation/need_help_screen.dart';
import '../features/settings/presentation/privacy_policy_screen.dart';
import '../features/settings/presentation/terms_conditions_screen.dart';
import '../features/settings/presentation/refund_policy_screen.dart';
import '../features/settings/presentation/about_app_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/profile/presentation/change_mpin_screen.dart';
import '../features/profile/presentation/bank_details_screen.dart';
import '../features/profile/presentation/add_bank_screen.dart';
import '../features/profile/presentation/kyc_screen.dart';
import '../features/profile/presentation/personal_info_screen.dart';
import '../features/commission/presentation/commission_slab_screen.dart';
import 'shell_scaffold.dart';

// ─── Router Provider ──────────────────────────────────────────────────────────

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final sessionListenable = _SessionListenable(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: sessionListenable,
    redirect: (context, state) {
      final sessionAsync = ref.read(sessionProvider);
      final isAuthenticated = sessionAsync.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == RouteNames.splash;

      // Allow splash to always render (it handles its own redirect logic)
      if (isSplash) return null;

      // Unauthenticated → redirect to OTP login
      if (!isAuthenticated && !isAuthRoute) {
        return RouteNames.otpLogin;
      }

      // Authenticated → redirect away from auth screens
      if (isAuthenticated && isAuthRoute) {
        return RouteNames.dashboard;
      }

      return null; // No redirect needed
    },
    routes: [
      // ─── Splash ────────────────────────────────────────────────────
        GoRoute(
          path: RouteNames.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: RouteNames.onboarding,
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        ),

      // ─── Authentication ────────────────────────────────────────────
      GoRoute(
        path: RouteNames.otpLogin,
        name: 'otp-login',
        pageBuilder: (context, state) => _slideUpPage(
          state: state,
          child: AppAuthConfig.provider == AuthProviderType.msg91 
              ? const Msg91LoginScreen() 
              : const LoginScreen(),
        ),
        routes: [
          GoRoute(
            path: 'verify',
            name: 'otp-verify',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              
              if (AppAuthConfig.provider == AuthProviderType.msg91) {
                final phone = extra['phone'] as String? ?? '';
                return _slideRightPage(
                  state: state,
                  child: Msg91OtpScreen(phone: phone),
                );
              } else {
                final verificationId = extra['verificationId'] as String? ?? '';
                final phone = extra['phone'] as String? ?? '';
                return _slideRightPage(
                  state: state,
                  child: OtpScreen(verificationId: verificationId, phone: phone),
                );
              }
            },
          ),
        ],
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _slideUpPage(
            state: state,
            child: RegistrationScreen(
              phone: extra['phone'] ?? '',
              firebaseUid: extra['firebaseUid'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/need-help',
        name: 'need-help',
        pageBuilder: (context, state) {
          final txn = state.extra as WalletTransaction;
          return _slideUpPage(
            state: state,
            child: NeedHelpScreen(transaction: txn),
          );
        },
      ),
      // GoRoute(
      //   path: RouteNames.mpinSetup,
      //   name: 'mpin-setup',
      //   pageBuilder: (context, state) => _slideRightPage(
      //     state: state,
      //     child: const MpinSetupScreen(),
      //   ),
      // ),
      // GoRoute(
      //   path: RouteNames.biometricPrompt,
      //   name: 'biometric',
      //   pageBuilder: (context, state) => _slideRightPage(
      //     state: state,
      //     child: const BiometricPromptScreen(),
      //   ),
      // ),

      // ─── Shell (Bottom Nav) ────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.dashboard,
                name: 'dashboard',
                pageBuilder: (context, state) => _fadePage(
                  state: state,
                  child: const DashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.history,
                name: 'history',
                pageBuilder: (context, state) => _fadePage(
                  state: state,
                  child: const HistoryScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'detail/:txnId',
                    name: 'transaction-detail',
                    pageBuilder: (context, state) => _slideRightPage(
                      state: state,
                      child: TransactionDetailsScreen(
                        txnId: state.pathParameters['txnId'] ?? '',
                        transaction: state.extra as WalletTransaction?,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Services branch — grid of all available services
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shell/services',
                name: 'services',
                pageBuilder: (context, state) => _fadePage(
                  state: state,
                  child: const ServicesScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.wallet,
                name: 'wallet',
                pageBuilder: (context, state) => _fadePage(
                  state: state,
                  child: const WalletScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'statement',
                    name: 'wallet-statement',
                    pageBuilder: (c, s) => _slideRightPage(
                      state: s,
                      child: const WalletStatementScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'topup',
                    name: 'wallet-topup',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (c, s) => _slideUpPage(
                      state: s,
                      child: const WalletTopupScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profileView,
                name: 'profile',
                pageBuilder: (context, state) => _fadePage(
                  state: state,
                  child: const ProfileScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'change-mpin',
                    name: 'change-mpin',
                    pageBuilder: (c, s) => _slideRightPage(
                      state: s,
                      child: const ChangeMpinScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'personal-info',
                    name: 'personal-info',
                    pageBuilder: (c, s) => _slideRightPage(
                      state: s,
                      child: const PersonalInfoScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'kyc',
                    name: 'kyc',
                    pageBuilder: (c, s) => _slideRightPage(
                      state: s,
                      child: const KycScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'commission-slab',
                    name: 'commission-slab',
                    pageBuilder: (c, s) => _slideRightPage(
                      state: s,
                      child: const CommissionSlabScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'bank',
                    name: 'bank-details',
                    pageBuilder: (c, s) => _slideRightPage(
                      state: s,
                      child: const BankDetailsScreen(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'add-bank',
                        name: 'add-bank',
                        pageBuilder: (c, s) {
                          final extra = s.extra as Map<String, dynamic>?;
                          return _slideUpPage(
                            state: s,
                            child: AddBankScreen(extraData: extra),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'biometric',
                    name: 'biometric-settings',
                    pageBuilder: (c, s) => _slideRightPage(
                      state: s,
                      child: const _PlaceholderScreen(title: 'Biometric Settings'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ─── Feature Routes (push over shell) ────────────────────────
      GoRoute(
        path: RouteNames.mobileRecharge,
        name: 'mobile-recharge',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const MobileRechargeScreen()),
      ),
      GoRoute(
        path: RouteNames.rechargePlans,
        name: 'mobile-recharge-plans',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const PlanSelectionScreen()),
      ),
      GoRoute(
        path: RouteNames.rechargeConfirm,
        name: 'mobile-recharge-confirm',
        pageBuilder: (c, s) => _slideUpPage(state: s, child: const RechargeConfirmationScreen()),
      ),
      GoRoute(
        path: RouteNames.rechargeReceipt,
        name: 'mobile-recharge-receipt',
        pageBuilder: (c, s) {
          final receipt = s.extra as RechargeReceipt?;
          if (receipt == null) {
            return _fadePage(state: s, child: const Scaffold(body: Center(child: Text('Invalid Receipt'))));
          }
          return _fadePage(state: s, child: RechargeReceiptScreen(receipt: receipt));
        },
      ),
      GoRoute(
        path: RouteNames.dthRecharge,
        name: 'dth-recharge',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const DthRechargeScreen()),
      ),
      GoRoute(
        path: RouteNames.dthPlans,
        name: 'dth-plans',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const DthPlansScreen()),
      ),
      GoRoute(
        path: RouteNames.dthConfirm,
        name: 'dth-confirm',
        pageBuilder: (c, s) => _slideUpPage(state: s, child: const DthConfirmationScreen()),
      ),
      GoRoute(
        path: RouteNames.dthReceipt,
        name: 'dth-receipt',
        pageBuilder: (c, s) {
          final receipt = s.extra as RechargeReceipt?;
          if (receipt == null) {
            return _fadePage(state: s, child: const Scaffold(body: Center(child: Text('Invalid Receipt'))));
          }
          return _fadePage(state: s, child: DthReceiptScreen(receipt: receipt));
        },
      ),
      GoRoute(
        path: RouteNames.bbps,
        name: 'bbps',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const BbpsScreen()),
      ),
      GoRoute(
        path: RouteNames.bbpsStateSelection,
        name: 'bbps-states',
        pageBuilder: (c, s) {
          final category = s.pathParameters['category'] ?? 'electricity';
          return _slideRightPage(state: s, child: BbpsStateSelectionScreen(category: category));
        },
      ),
      GoRoute(
        path: RouteNames.bbpsBiller,
        name: 'bbps-biller',
        pageBuilder: (c, s) {
          final category = s.pathParameters['category'] ?? 'electricity';
          final stateParam = s.uri.queryParameters['state'];
          return _slideRightPage(state: s, child: BbpsBillerScreen(category: category, state: stateParam));
        },
      ),
      GoRoute(
        path: RouteNames.bbpsBillFetch,
        name: 'bbps-fetch',
        pageBuilder: (c, s) {
          final billerId = s.pathParameters['billerId'] ?? '';
          return _slideRightPage(state: s, child: BbpsFetchScreen(billerId: billerId));
        },
      ),
      GoRoute(
        path: RouteNames.bbpsPayConfirm,
        name: 'bbps-pay',
        pageBuilder: (c, s) {
          final billerId = s.pathParameters['billerId'] ?? '';
          return _slideUpPage(state: s, child: BbpsPayConfirmScreen(billerId: billerId));
        },
      ),
      GoRoute(
        path: RouteNames.aeps,
        name: 'aeps',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const AepsScreen()),
      ),
      GoRoute(
        path: RouteNames.aepsCashWithdrawal,
        name: 'aeps-cash-withdrawal',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const AepsTransactionScreen()),
      ),
      GoRoute(
        path: RouteNames.aepsBalanceEnquiry,
        name: 'aeps-balance-enquiry',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const AepsTransactionScreen()),
      ),
      GoRoute(
        path: RouteNames.aepsMiniStatement,
        name: 'aeps-mini-statement',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const AepsTransactionScreen()),
      ),
      GoRoute(
        path: RouteNames.aepsAadhaarPay,
        name: 'aeps-aadhaar-pay',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const AepsTransactionScreen()),
      ),
      GoRoute(
        path: RouteNames.aepsBiometric,
        name: 'aeps-biometric',
        pageBuilder: (c, s) => _slideUpPage(state: s, child: const BiometricAuthScreen()),
      ),
      GoRoute(
        path: RouteNames.aepsReceipt,
        name: 'aeps-receipt',
        pageBuilder: (c, s) {
          final result = s.extra as AepsResult?;
          if (result == null) {
            return _fadePage(state: s, child: const Scaffold(body: Center(child: Text('Invalid Receipt'))));
          }
          return _fadePage(state: s, child: AepsReceiptScreen(result: result));
        },
      ),
      GoRoute(
        path: RouteNames.dmt,
        name: 'dmt',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const DmtScreen()),
      ),
      GoRoute(
        path: RouteNames.dmtBeneficiaries,
        name: 'dmt-beneficiaries',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const DmtBeneficiariesScreen()),
      ),
      GoRoute(
        path: RouteNames.dmtAddBeneficiary,
        name: 'dmt-add-beneficiary',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const DmtAddBeneficiaryScreen()),
      ),
      GoRoute(
        path: RouteNames.dmtTransfer,
        name: 'dmt-transfer',
        pageBuilder: (c, s) {
          final beneficiaryId = s.pathParameters['beneficiaryId'] ?? '';
          return _slideRightPage(state: s, child: DmtTransferScreen(beneficiaryId: beneficiaryId));
        },
      ),
      GoRoute(
        path: RouteNames.dmtReceipt,
        name: 'dmt-receipt',
        pageBuilder: (c, s) {
          final result = s.extra as DmtResult?;
          if (result == null) {
            return _fadePage(state: s, child: const Scaffold(body: Center(child: Text('Invalid Receipt'))));
          }
          return _fadePage(state: s, child: DmtReceiptScreen(result: result));
        },
      ),
      GoRoute(
        path: RouteNames.insurance,
        name: 'insurance',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const InsuranceScreen()),
      ),
      GoRoute(
        path: RouteNames.insuranceProduct,
        name: 'insurance-product',
        pageBuilder: (c, s) {
          final productId = s.pathParameters['productId'] ?? '';
          return _slideRightPage(state: s, child: InsuranceProductScreen(productId: productId));
        },
      ),
      GoRoute(
        path: RouteNames.loan,
        name: 'loan',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const LoanScreen()),
      ),
      GoRoute(
        path: RouteNames.loanEmi,
        name: 'loan-emi',
        pageBuilder: (c, s) {
          final providerId = s.pathParameters['providerId'] ?? '';
          return _slideRightPage(state: s, child: LoanEmiScreen(providerId: providerId));
        },
      ),
      GoRoute(
        path: RouteNames.notifications,
        name: 'notifications',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const NotificationsScreen()),
      ),
      GoRoute(
        path: RouteNames.settings,
        name: 'settings',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const SettingsScreen()),
      ),
      GoRoute(
        path: RouteNames.privacyPolicy,
        name: 'privacy-policy',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: RouteNames.termsAndConditions,
        name: 'terms-and-conditions',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const TermsConditionsScreen()),
      ),
      GoRoute(
        path: RouteNames.refundPolicy,
        name: 'refund-policy',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const RefundPolicyScreen()),
      ),
      GoRoute(
        path: RouteNames.aboutApp,
        name: 'about-app',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const AboutAppScreen()),
      ),
      GoRoute(
        path: RouteNames.support,
        name: 'support',
        pageBuilder: (c, s) => _slideRightPage(state: s, child: const SupportScreen()),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Route not found: ${state.uri}'),
          ],
        ),
      ),
    ),
  );
});

// ─── Page Transition Helpers ──────────────────────────────────────────────────

CustomTransitionPage<T> _fadePage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: child,
      );
    },
  );
}

CustomTransitionPage<T> _slideRightPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: fade, child: child),
      );
    },
  );
}

CustomTransitionPage<T> _slideUpPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));
      return SlideTransition(position: slide, child: child);
    },
  );
}

// ─── Auth Redirect Listenable ─────────────────────────────────────────────────

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
}

// ─── Scan Placeholder ─────────────────────────────────────────────────────────
// The real scanner is in Phase 5+ (mobile_scanner package with camera permission)

class _ScanPlaceholder extends StatelessWidget {
  const _ScanPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Scanner')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('QR Scanner — Coming in Phase 5'),
          ],
        ),
      ),
    );
  }
}

// ─── Generic Placeholder Screen ───────────────────────────────────────────────
// Used for profile sub-routes that are not yet implemented.

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title — coming soon'),
      ),
    );
  }
}
