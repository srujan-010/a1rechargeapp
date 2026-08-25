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
import '../providers/wallet_mpin_provider.dart';

class WalletMpinScreen extends ConsumerWidget {
  const WalletMpinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mpinState = ref.watch(walletMpinProvider);
    final bool isConfigured = mpinState.walletMpinConfigured ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wallet MPIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              // Wallet MPIN Status Card
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
                        isConfigured ? Icons.verified_user_rounded : Icons.payment_outlined,
                        size: 40,
                        color: isConfigured ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      isConfigured ? 'Wallet MPIN Active' : 'Wallet MPIN Not Configured',
                      style: AppTextTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isConfigured
                          ? 'Your 6-digit Wallet MPIN is active and authorizing your wallet transactions & debits.'
                          : 'Set up a 6-digit Wallet MPIN to securely authorize wallet payments.',
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
                        isConfigured ? '✓ Wallet MPIN Configured' : 'Setup Required',
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
                        title: const Text('Change Wallet MPIN', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Update your 6-digit payment MPIN'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push(RouteNames.changeMpin),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.restore, color: AppColors.primaryBlue),
                        title: const Text('Forgot / Reset Wallet MPIN', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Reset your payment MPIN via Mobile OTP'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push(RouteNames.forgotMpin),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                AppButton(
                  label: 'Set Up Wallet MPIN',
                  onPressed: () => context.push(RouteNames.createMpin),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // Advisory Card
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
                        'Security Tip: Wallet MPIN is required ONLY to authorize payments from your A1 Recharge wallet. It cannot unlock the application.',
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
