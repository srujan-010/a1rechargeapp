import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_skeleton.dart';
import 'insurance_providers.dart';

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(insuranceProvidersListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Insurance Premium'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Text(
                'Select Insurance Provider',
                style: AppTextTheme.textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: providersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.pagePadding),
                  child: ListSkeleton(count: 6),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (providers) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    itemCount: providers.length,
                    itemBuilder: (context, index) {
                      final provider = providers[index];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        onTap: () {
                          ref.read(insuranceFlowProvider.notifier).selectProvider(provider);
                          context.push(RouteNames.insuranceProduct.replaceFirst(':productId', provider.id));
                        },
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.surfaceVariant,
                            child: Icon(Icons.health_and_safety, color: AppColors.primaryBlue),
                          ),
                          title: Text(provider.name, style: AppTextTheme.textTheme.titleSmall),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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