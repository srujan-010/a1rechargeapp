import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/models/aeps_models.dart';
import 'aeps_providers.dart';

class AepsScreen extends ConsumerWidget {
  const AepsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = [
      {
        'title': 'Cash Withdrawal',
        'icon': Icons.payments_outlined,
        'type': AepsTransactionType.cashWithdrawal,
        'route': RouteNames.aepsCashWithdrawal,
      },
      {
        'title': 'Balance Enquiry',
        'icon': Icons.account_balance_wallet_outlined,
        'type': AepsTransactionType.balanceEnquiry,
        'route': RouteNames.aepsBalanceEnquiry,
      },
      {
        'title': 'Mini Statement',
        'icon': Icons.receipt_long_outlined,
        'type': AepsTransactionType.miniStatement,
        'route': RouteNames.aepsMiniStatement,
      },
      {
        'title': 'Aadhaar Pay',
        'icon': Icons.fingerprint,
        'type': AepsTransactionType.aadhaarPay,
        'route': RouteNames.aepsAadhaarPay,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AEPS Services'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                backgroundColor: AppColors.primaryBlueLight,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.fingerprint, color: AppColors.primaryBlue, size: 28),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aadhaar Enabled Payments',
                            style: AppTextTheme.textTheme.titleMedium?.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Use your Aadhaar to perform banking transactions',
                            style: AppTextTheme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              Text('Select Service', style: AppTextTheme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.1,
                ),
                itemCount: types.length,
                itemBuilder: (context, index) {
                  final item = types[index];
                  return _AepsServiceCard(
                    title: item['title'] as String,
                    icon: item['icon'] as IconData,
                    onTap: () {
                      ref.read(aepsFlowProvider.notifier).reset();
                      ref.read(aepsFlowProvider.notifier).setTransactionType(item['type'] as AepsTransactionType);
                      // Start the flow by going to the transaction screen
                      context.push(item['route'] as String);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AepsServiceCard extends StatelessWidget {
  const _AepsServiceCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });
  
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: AppColors.primaryBlue),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTextTheme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}