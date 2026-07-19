// lib/core/widgets/app_card.dart
// Standardized card with soft shadow — no hard borders.
// Always use this instead of Card() directly.

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.onTap,
    this.elevation = 1.0,
    this.semanticsLabel,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final VoidCallback? onTap;
  final double elevation;
  final String? semanticsLabel;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.card;
    final content = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? AppColors.cardWhite) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) {
      return Semantics(
        label: semanticsLabel,
        container: semanticsLabel != null,
        child: margin != null ? Padding(padding: margin!, child: content) : content,
      );
    }

    return Semantics(
      label: semanticsLabel,
      button: semanticsLabel != null,
      child: Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A gradient-background card used for the wallet balance display.
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: AppColors.primaryGradient,
    ),
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final LinearGradient gradient;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      gradient: gradient,
      borderRadius: borderRadius ?? AppRadius.xl,
      child: child,
    );
  }
}
