import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_skeleton.dart';
import 'bbps_providers.dart';

class BbpsBillerScreen extends ConsumerWidget {
  const BbpsBillerScreen({super.key, required this.category});
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billersAsync = ref.watch(billersProvider(category));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Select $category Biller'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Search billers...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  // Local search filtering can be added here
                },
              ),
            ),
            Expanded(
              child: billersAsync.when(
                loading: () => const ListSkeleton(count: 8),
                error: (e, _) => Center(child: Text('Error loading billers: $e')),
                data: (billers) {
                  if (billers.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No billers found',
                      description: 'We could not find any billers for this category in your region.',
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    itemCount: billers.length,
                    itemBuilder: (context, index) {
                      final biller = billers[index];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.surfaceVariant,
                            child: Text(
                              biller.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: AppColors.primaryBlue),
                            ),
                          ),
                          title: Text(
                            biller.name,
                            style: AppTextTheme.textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            ref.read(bbpsFlowProvider.notifier).setBiller(biller);
                            context.push(RouteNames.bbpsBillFetch.replaceFirst(':billerId', biller.id));
                          },
                        ),
                      );
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
