import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_skeleton.dart';
import 'dmt_providers.dart';

class DmtBeneficiariesScreen extends ConsumerWidget {
  const DmtBeneficiariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dmtFlowProvider);
    final remitter = state.currentRemitter;
    final bensAsync = ref.watch(dmtBeneficiariesProvider);

    if (remitter == null) {
      return const Scaffold(body: Center(child: Text('Invalid State')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Beneficiaries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              context.push(RouteNames.dmtAddBeneficiary);
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Remitter Summary Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: AppColors.primaryBlue,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      remitter.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          remitter.name,
                          style: AppTextTheme.textTheme.titleSmall?.copyWith(color: Colors.white),
                        ),
                        Text(
                          remitter.mobileNumber,
                          style: AppTextTheme.textTheme.labelSmall?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Limit Available',
                        style: AppTextTheme.textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                      Text(
                        CurrencyFormatter.fromPaise(remitter.availableLimitPaise),
                        style: AppTextTheme.textTheme.titleSmall?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: bensAsync.when(
                loading: () => const ListSkeleton(count: 5),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (bens) {
                  if (bens.isEmpty) {
                    return EmptyStateWidget(
                      title: 'No Beneficiaries',
                      description: 'You have not added any beneficiaries yet.',
                      ctaLabel: 'Add Beneficiary',
                      onCtaTap: () => context.push(RouteNames.dmtAddBeneficiary),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.pagePadding),
                    itemCount: bens.length,
                    itemBuilder: (context, index) {
                      final ben = bens[index];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.surfaceVariant,
                                    child: const Icon(Icons.account_balance, color: AppColors.primaryBlue),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ben.name, style: AppTextTheme.textTheme.titleSmall),
                                        Text('${ben.bankName} • ${ben.accountNumber}', 
                                            style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  if (ben.isVerified)
                                    const Icon(Icons.verified, color: AppColors.success, size: 20)
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        // Account verification logic mock
                                      },
                                      child: const Text('Verify A/c'),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        ref.read(dmtFlowProvider.notifier).setBeneficiary(ben);
                                        context.push(RouteNames.dmtTransfer.replaceFirst(':beneficiaryId', ben.id));
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryBlue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Transfer'),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
