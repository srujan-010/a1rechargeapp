// lib/features/commission/domain/commission_repository.dart
// Abstract interface for commission data access.
// Nothing here imports Dio, Hive, or Flutter widgets.
// See data/commission_repository_mock.dart and data/commission_repository_impl.dart.

import 'models/commission_slab.dart';
import 'models/earned_commission_entry.dart';

abstract class CommissionRepository {
  /// Returns all currently active commission slabs.
  Future<List<CommissionSlab>> getActiveSlabs();

  /// Returns earned commission entries, optionally filtered by date range.
  /// Both [from] and [to] are inclusive. Omit for all-time.
  Future<List<EarnedCommissionEntry>> getEarnedEntries({
    DateTime? from,
    DateTime? to,
  });
}
