import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_card.dart';
import 'providers/dth_providers.dart';

class DthPlansScreen extends ConsumerWidget {
  const DthPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowState = ref.watch(dthFlowProvider);
    final operator = flowState.selectedOperator;

    if (operator == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('DTH Packs')),
        body: const Center(child: Text('No operator selected')),
      );
    }

    AppLogger.info('[DTH PACKS] Operator: ${operator.name} (id: ${operator.id}, code: ${operator.code})', tag: 'DthPlansUI');
    final packsAsync = ref.watch(dthPacksProvider(operator));

    return Scaffold(
      appBar: AppBar(
        title: Text('${operator.name} Packs'),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: AppColors.background,
      body: packsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('Fetching DTH packs from provider...'),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 56),
                const SizedBox(height: AppSpacing.md),
                Text(
                  err.toString().contains('Failed to parse') ? 'Pack Parsing Failure' : 'Failed to Load Packs',
                  style: AppTextTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: AppTextTheme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(dthPacksProvider(operator)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
        data: (packs) {
          return const Center(child: Text('DTH Packs are disabled'));
        },
      ),
    );
  }
}
