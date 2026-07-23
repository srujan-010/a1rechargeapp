import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/route_names.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_text_theme.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/loading_skeleton.dart';
import '../../domain/models/gas_models.dart';
import '../gas_providers.dart';

class GasOperatorSelectionScreen extends ConsumerStatefulWidget {
  const GasOperatorSelectionScreen({super.key});

  @override
  ConsumerState<GasOperatorSelectionScreen> createState() => _GasOperatorSelectionScreenState();
}

class _GasOperatorSelectionScreenState extends ConsumerState<GasOperatorSelectionScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operatorsAsync = ref.watch(gasOperatorsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Select Gas Provider', style: AppTextTheme.textTheme.titleMedium),
        elevation: 0,
        backgroundColor: AppColors.cardWhite,
        scrolledUnderElevation: 4,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.cardWhite,
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by provider name...',
                    hintStyle: const TextStyle(color: AppColors.textHint),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.cardWhite,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: operatorsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: ListSkeleton(count: 8),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Failed to load providers', style: AppTextTheme.textTheme.titleSmall),
                      TextButton(
                        onPressed: () => ref.refresh(gasOperatorsProvider),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
                data: (operators) {
                  final activeOperators = operators.where((o) => o.isActive).toList();
                  final filteredOperators = activeOperators.where((o) {
                    return o.name.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (activeOperators.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No providers found',
                      description: 'We could not find any active gas providers.',
                    );
                  }

                  if (filteredOperators.isEmpty) {
                    return EmptyStateWidget(
                      title: 'No matches found',
                      description: 'We could not find a provider matching "$_searchQuery".',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filteredOperators.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final operator = filteredOperators[index];
                      return _ProviderCard(operator: operator);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.operator});

  final GasOperator operator;

  @override
  Widget build(BuildContext context) {
    // Determine subtitle
    String subtitle = 'Piped Gas';
    if (operator.name.toLowerCase().contains('hp gas')) {
      subtitle = 'LPG';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push(RouteNames.gasBillFetch.replaceFirst(':billerId', operator.id), extra: operator);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE9E7),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Center(
                    child: operator.iconUrl != null && operator.iconUrl!.isNotEmpty
                        ? Image.network(operator.iconUrl!, width: 24, height: 24, errorBuilder: (_, __, ___) => _fallbackIcon())
                        : _fallbackIcon(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        operator.name,
                        style: AppTextTheme.textTheme.titleSmall?.copyWith(fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextTheme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return const Icon(Icons.local_fire_department, color: Color(0xFFD84315), size: 24);
  }
}
