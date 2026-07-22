import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../models/mobile_plan.dart';
import 'recharge_providers.dart';

class PlanSelectionScreen extends ConsumerStatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  ConsumerState<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends ConsumerState<PlanSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rechargeFlowProvider);
    
    if (state.operator == null || state.circle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Plan')),
        body: const Center(child: Text('Operator and Circle not selected.')),
      );
    }

    final providerParam = (operatorId: state.operator!.shortCode ?? state.operator!.id, circle: state.circle!.code ?? state.circle!.id, serviceType: state.operator!.type.name);
    final plansAsync = ref.watch(plansProvider(providerParam));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Plan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding, vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${state.operator!.name} - ${state.circle!.state}',
                      style: AppTextTheme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search amount, validity, benefits...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ) : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.all(AppSpacing.sm),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: plansAsync.when(
        loading: () => const ListSkeleton(count: 8),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Could not load plans: $e', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.refresh(plansProvider(providerParam)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (categories) {
          final allPlans = categories.expand((c) => c.plans).toList();
          
          final filteredPlans = allPlans.where((p) {
            if (_searchQuery.isEmpty) return true;
            return (p.desc ?? '').toLowerCase().contains(_searchQuery) ||
                   (p.rs ?? '').contains(_searchQuery) ||
                   (p.validity ?? '').toLowerCase().contains(_searchQuery);
          }).toList();

          if (filteredPlans.isEmpty) {
            return const EmptyStateWidget(
              title: 'No plans found',
              description: 'Try adjusting your search criteria.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              return ref.refresh(plansProvider(providerParam));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: filteredPlans.length,
              itemBuilder: (context, index) {
                return _PlanTile(plan: filteredPlans[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile({required this.plan});
  final MobilePlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rsVal = double.tryParse(plan.rs ?? '0') ?? 0;
    final paiseVal = (rsVal * 100).toInt();

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
                    CurrencyFormatter.fromPaise(paiseVal),
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
                      'Validity: ${plan.validity ?? "NA"}',
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
                plan.desc ?? '',
                style: AppTextTheme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
