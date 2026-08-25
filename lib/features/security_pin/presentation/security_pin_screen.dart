import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/security_pin_provider.dart';

class SecurityPinScreen extends ConsumerWidget {
  const SecurityPinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinState = ref.watch(securityPinProvider);
    final bool isConfigured = pinState.securityPinConfigured ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Security PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AppNavigation.pop(context, fallbackRoute: RouteNames.profileView),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Security Status Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isConfigured ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isConfigured ? Icons.verified_user_rounded : Icons.shield_outlined,
                        size: 40,
                        color: isConfigured ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      isConfigured ? 'Security PIN Active' : 'Security PIN Not Configured',
                      style: AppTextTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isConfigured
                          ? 'Your 6-digit Security PIN protects access to your A1 Recharge account.'
                          : 'Set up a 6-digit Security PIN to protect access to your A1 Recharge account.',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isConfigured ? const Color(0xFF16A34A).withValues(alpha: 0.1) : const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isConfigured ? '✓ Security PIN Active' : 'Setup Required',
                        style: TextStyle(
                          color: isConfigured ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Actions List
              if (isConfigured) ...[
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_reset, color: AppColors.primaryBlue),
                        title: const Text('Change Security PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Update your existing 6-digit PIN'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push(RouteNames.changeSecurityPin),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.restore, color: AppColors.primaryBlue),
                        title: const Text('Forgot / Reset Security PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Reset your Security PIN via Mobile OTP'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push(RouteNames.forgotSecurityPin),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                AppButton(
                  label: 'Set Up Security PIN',
                  onPressed: () => context.push(RouteNames.createSecurityPin),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // Security Advisory Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Security Tip: Never share your Security PIN or Wallet MPIN with anyone, including A1 Recharge support representatives.',
                        style: AppTextTheme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
