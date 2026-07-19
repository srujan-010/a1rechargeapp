import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../domain/models/recharge_plan.dart';
import 'recharge_providers.dart';

class PlanSelectionScreen extends ConsumerWidget {
  const PlanSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechargeFlowProvider);
    
    if (state.operator == null || state.circle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Plan')),
        body: const Center(child: Text('Operator and Circle not selected.')),
      );
    }

    final plansAsync = ref.watch(
      plansProvider((operatorId: state.operator!.id, circle: state.circle!))
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Plan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding, vertical: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${state.operator!.name} - ${state.circle}',
                  style: AppTextTheme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: plansAsync.when(
        loading: () => const ListSkeleton(count: 8),
        error: (e, _) => Center(child: Text('Could not load plans: $e')),
        data: (plans) {
          if (plans.isEmpty) {
            return const EmptyStateWidget(
              title: 'No plans found',
              description: 'There are no plans available for this operator.',
            );
          }

          // Extract unique categories
          final categories = plans.map((p) => p.category.name).toSet().toList();

          return DefaultTabController(
            length: categories.length,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  labelColor: AppColors.primaryBlue,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryBlue,
                  tabs: categories.map((c) => Tab(text: c)).toList(),
                ),
                Expanded(
                  child: TabBarView(
                    children: categories.map((category) {
                      final categoryPlans = plans.where((p) => p.category.name == category).toList();
                      return ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        itemCount: categoryPlans.length,
                        itemBuilder: (context, index) {
                          return _PlanTile(plan: categoryPlans[index]);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile({required this.plan});
  final RechargePlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () {
          ref.read(rechargeFlowProvider.notifier).setPlan(plan);
          Navigator.pop(context); // Go back to Mobile Recharge screen
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    CurrencyFormatter.fromPaise(plan.pricePaise),
                    style: AppTextTheme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      'Validity: ${plan.validity}',
                      style: AppTextTheme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                plan.description,
                style: AppTextTheme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
