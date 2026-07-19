// lib/features/commission/presentation/commission_providers.dart
// Riverpod providers for commission data: slabs, earned summaries, period filtering.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/logger.dart';
import '../../../core/providers/core_providers.dart';
import '../data/commission_repository_impl.dart';
import '../data/commission_repository_mock.dart';
import '../domain/commission_repository.dart';
import '../domain/models/commission_slab.dart';
import '../domain/models/earned_commission_entry.dart';

// ─── Period Enum ─────────────────────────────────────────────────────────────

enum CommissionPeriod { today, thisWeek, thisMonth }

extension CommissionPeriodX on CommissionPeriod {
  String get label => switch (this) {
        CommissionPeriod.today => 'Today',
        CommissionPeriod.thisWeek => 'This Week',
        CommissionPeriod.thisMonth => 'This Month',
      };

  /// Returns the start of this period in local time, truncated to midnight.
  DateTime get fromDate {
    final now = DateTime.now();
    return switch (this) {
      CommissionPeriod.today => DateTime(now.year, now.month, now.day),
      CommissionPeriod.thisWeek =>
        DateTime(now.year, now.month, now.day - (now.weekday - 1)),
      CommissionPeriod.thisMonth => DateTime(now.year, now.month, 1),
    };
  }
}

// ─── Summary Model ────────────────────────────────────────────────────────────

/// Aggregated commission earned for a given period.
class EarnedCommissionSummary {
  const EarnedCommissionSummary({
    required this.totalEarned,
    required this.byOperator,
  });

  /// Total INR earned in the period.
  final double totalEarned;

  /// Keyed by operator name, value is INR amount earned from that operator.
  final Map<String, double> byOperator;

  bool get isEmpty => totalEarned == 0 && byOperator.isEmpty;

  static const EarnedCommissionSummary zero =
      EarnedCommissionSummary(totalEarned: 0, byOperator: {});
}

// ─── Repository Provider ──────────────────────────────────────────────────────

final commissionRepositoryProvider = Provider<CommissionRepository>((ref) {
  if (AppConfig.useMockApi) {
    AppLogger.info('Using MOCK CommissionRepository', tag: 'Providers');
    return CommissionRepositoryMock();
  }
  return CommissionRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

// ─── Active Slabs Provider ────────────────────────────────────────────────────

final activeCommissionSlabsProvider =
    FutureProvider<List<CommissionSlab>>((ref) async {
  final repo = ref.watch(commissionRepositoryProvider);
  return repo.getActiveSlabs();
});

// ─── Earned Commission Provider (per-period) ──────────────────────────────────

/// Returns aggregated commission summary for the given [CommissionPeriod].
/// Joins earned entries against active slabs by slabId to get operator names.
final earnedCommissionProvider = FutureProvider.family<EarnedCommissionSummary,
    CommissionPeriod>((ref, period) async {
  final repo = ref.watch(commissionRepositoryProvider);
  final slabsAsync = await ref.watch(activeCommissionSlabsProvider.future);

  final slabMap = {for (final s in slabsAsync) s.id: s};

  final from = period.fromDate;
  final to = DateTime.now();

  final List<EarnedCommissionEntry> entries =
      await repo.getEarnedEntries(from: from, to: to);

  if (entries.isEmpty) return EarnedCommissionSummary.zero;

  double total = 0;
  final Map<String, double> byOperator = {};

  for (final entry in entries) {
    total += entry.amountEarned;
    final slab = slabMap[entry.slabId];
    final operatorName = slab?.operatorName ?? 'Other';
    byOperator[operatorName] =
        (byOperator[operatorName] ?? 0) + entry.amountEarned;
  }

  return EarnedCommissionSummary(totalEarned: total, byOperator: byOperator);
});
