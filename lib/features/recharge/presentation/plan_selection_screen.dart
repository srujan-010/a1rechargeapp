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

    final providerParam = (operatorId: state.operator!.id, circle: state.circle!.id, serviceType: state.operator!.type.name);
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
        data: (plans) {
          final filteredPlans = plans.where((p) {
            if (_searchQuery.isEmpty) return true;
            return p.description.toLowerCase().contains(_searchQuery) ||
                   p.pricePaise.toString().contains(_searchQuery) ||
                   p.validity.toLowerCase().contains(_searchQuery) ||
                   p.category.name.toLowerCase().contains(_searchQuery) ||
                   (p.data != null && p.data!.toLowerCase().contains(_searchQuery)) ||
                   (p.voice != null && p.voice!.toLowerCase().contains(_searchQuery)) ||
                   (p.sms != null && p.sms!.toLowerCase().contains(_searchQuery));
          }).toList();

          if (filteredPlans.isEmpty) {
            return const EmptyStateWidget(
              title: 'No plans found',
              description: 'Try adjusting your search criteria.',
            );
          }

          final categories = filteredPlans.map((p) => p.category.name).toSet().toList();

          return RefreshIndicator(
            onRefresh: () async {
              return ref.refresh(plansProvider(providerParam));
            },
            child: DefaultTabController(
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
                        final categoryPlans = filteredPlans.where((p) => p.category.name == category).toList();
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
              if (plan.data != null || plan.voice != null || plan.sms != null) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1, color: AppColors.surfaceVariant),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (plan.data != null && plan.data!.isNotEmpty)
                      _buildFeature(Icons.data_usage, 'Data', plan.data!),
                    if (plan.voice != null && plan.voice!.isNotEmpty)
                      _buildFeature(Icons.phone, 'Calls', plan.voice!),
                    if (plan.sms != null && plan.sms!.isNotEmpty)
                      _buildFeature(Icons.message, 'SMS', plan.sms!),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(height: 4),
        Text(value, style: AppTextTheme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: AppTextTheme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
