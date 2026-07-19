// lib/core/widgets/empty_state_widget.dart
// Reusable empty state with Lottie animation, title, description, and optional CTA.

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../constants/asset_paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_theme.dart';
import 'app_button.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.description,
    this.lottieAsset,
    this.ctaLabel,
    this.onCtaTap,
    this.compact = false,
  });

  final String title;
  final String description;
  final String? lottieAsset;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact)
              Lottie.asset(
                lottieAsset ?? AssetPaths.lottieEmpty,
                width: 200,
                height: 200,
                repeat: true,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: AppColors.textHint,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextTheme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCtaTap != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: ctaLabel!,
                onPressed: onCtaTap,
                fullWidth: false,
                variant: AppButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// lib/core/widgets/error_state_widget.dart
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact)
              Lottie.asset(
                AssetPaths.lottieFailure,
                width: 160,
                height: 160,
                repeat: false,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Something went wrong',
              style: AppTextTheme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Try Again',
                onPressed: onRetry,
                variant: AppButtonVariant.outline,
                fullWidth: false,
                prefixIcon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
