import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../domain/models/bbps_models.dart';
import 'bbps_providers.dart';

class BbpsBillerScreen extends ConsumerStatefulWidget {
  const BbpsBillerScreen({super.key, required this.category, this.state});
  final String category;
  final String? state;

  @override
  ConsumerState<BbpsBillerScreen> createState() => _BbpsBillerScreenState();
}

class _BbpsBillerScreenState extends ConsumerState<BbpsBillerScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = BillerFetchParams(category: widget.category, state: widget.state);
    final billersAsync = ref.watch(billersProvider(params));

    final titleText = widget.state != null 
        ? '${widget.category[0].toUpperCase()}${widget.category.substring(1)} - ${widget.state}'
        : 'Select ${widget.category} Provider';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(titleText, style: AppTextTheme.textTheme.titleMedium),
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
                    hintText: 'Search by biller name...',
                    hintStyle: TextStyle(color: AppColors.textHint),
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
              child: billersAsync.when(
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
                        onPressed: () => ref.refresh(billersProvider(params)),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
                data: (billers) {
                  final filteredBillers = billers.where((b) {
                    return b.name.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (billers.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No billers found',
                      description: 'We could not find any providers for this category.',
                    );
                  }

                  if (filteredBillers.isEmpty) {
                    return EmptyStateWidget(
                      title: 'No matches found',
                      description: 'We could not find a provider matching "$_searchQuery".',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filteredBillers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final biller = filteredBillers[index];
                      return _BillerCard(biller: biller, fallbackState: widget.state ?? 'India');
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

class _BillerCard extends ConsumerWidget {
  const _BillerCard({required this.biller, required this.fallbackState});

  final Biller biller;
  final String fallbackState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            ref.read(bbpsFlowProvider.notifier).setBiller(biller);
            context.push(RouteNames.bbpsBillFetch.replaceFirst(':billerId', biller.id));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Center(
                    child: biller.iconUrl.isNotEmpty
                        ? Image.network(biller.iconUrl, width: 24, height: 24, errorBuilder: (_, __, ___) => _fallbackIcon())
                        : _fallbackIcon(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        biller.name,
                        style: AppTextTheme.textTheme.titleSmall?.copyWith(fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fallbackState,
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
    return Text(
      biller.name.substring(0, 1).toUpperCase(),
      style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
    );
  }
}
