// lib/features/commission/presentation/earned_commission_card.dart
// Dashboard section widget: Compact Analytics Card
// Shows total commission for Today/Week/Month vs previous period.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../dashboard/presentation/dashboard_providers.dart';

enum AnalyticsPeriod { today, week, month }

extension AnalyticsPeriodX on AnalyticsPeriod {
  String get label => switch (this) {
        AnalyticsPeriod.today => 'Today',
        AnalyticsPeriod.week => 'Week',
        AnalyticsPeriod.month => 'Month',
      };
      
  String get apiValue => switch (this) {
        AnalyticsPeriod.today => 'today',
        AnalyticsPeriod.week => 'week',
        AnalyticsPeriod.month => 'month',
      };
}

class EarnedCommissionCard extends ConsumerStatefulWidget {
  const EarnedCommissionCard({super.key});

  @override
  ConsumerState<EarnedCommissionCard> createState() =>
      _EarnedCommissionCardState();
}

class _EarnedCommissionCardState extends ConsumerState<EarnedCommissionCard> {
  AnalyticsPeriod _period = AnalyticsPeriod.today;

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(dashboardAnalyticsProvider(_period.apiValue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header + period toggle ───────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Analytics',
              style: AppTextTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            _SegmentedControl(
              selected: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Card body ────────────────────────────────────────────────
        AppCard(
          padding: EdgeInsets.zero,
          onTap: () => context.push(RouteNames.commissionSlab),
          child: analyticsAsync.when(
            loading: () => const _AnalyticsSkeleton(),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(dashboardAnalyticsProvider(_period.apiValue)),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ),
            ),
            data: (data) {
              final current = data['currentPeriod'] as Map<String, dynamic>? ?? {};
              final prev = data['previousPeriod'] as Map<String, dynamic>? ?? {};
              
              final currentCommission = (current['commission'] as num?)?.toInt() ?? 0;
              final prevCommission = (prev['commission'] as num?)?.toInt() ?? 0;
              
              if (currentCommission == 0 && prevCommission == 0) {
                return const _EmptyState();
              }
              
              return _AnalyticsData(
                currentCommission: currentCommission,
                prevCommission: prevCommission,
                period: _period,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Segmented Control ───────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.selected, required this.onChanged});

  final AnalyticsPeriod selected;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AnalyticsPeriod.values.map((p) {
          final isSelected = p == selected;
          return GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Text(
                p.label,
                style: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Data View ────────────────────────────────────────────────────────────────

class _AnalyticsData extends StatelessWidget {
  const _AnalyticsData({
    required this.currentCommission,
    required this.prevCommission,
    required this.period,
  });

  final int currentCommission;
  final int prevCommission;
  final AnalyticsPeriod period;

  @override
  Widget build(BuildContext context) {
    // Calculate percentage change
    double percentChange = 0;
    if (prevCommission > 0) {
      percentChange = ((currentCommission - prevCommission) / prevCommission) * 100;
    } else if (currentCommission > 0) {
      percentChange = 100; // infinite growth from 0, cap it at something sensible or show "New"
    }

    final isPositive = percentChange >= 0;
    final changeColor = isPositive ? AppColors.success : AppColors.error;
    final changeIcon = isPositive ? Icons.trending_up : Icons.trending_down;
    final changeText = prevCommission == 0 && currentCommission > 0 
      ? '+100%' 
      : '${isPositive ? '+' : ''}${percentChange.toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commission Earned',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.fromRupees(currentCommission / 100),
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: changeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(changeIcon, color: changeColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  changeText,
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryBlueLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch,
              color: AppColors.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start Earning',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Do your first recharge to unlock commissions.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => context.push(RouteNames.mobileRecharge),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            child: const Text('Start', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.cardWhite,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 100, height: 14, color: Colors.white),
                const SizedBox(height: 12),
                Container(width: 140, height: 32, color: Colors.white),
              ],
            ),
            Container(width: 70, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
          ],
        ),
      ),
    );
  }
}
