// lib/features/commission/data/commission_repository_impl.dart
// Real API-backed implementation of CommissionRepository.
// Injected when USE_MOCK_API=false.

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/logger.dart';
import '../domain/commission_repository.dart';
import '../domain/models/commission_slab.dart';
import '../domain/models/earned_commission_entry.dart';

class CommissionRepositoryImpl implements CommissionRepository {
  CommissionRepositoryImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<CommissionSlab>> getActiveSlabs() async {
    try {
      final response = await apiClient.get<List<dynamic>>(
        ApiEndpoints.commissionSlabs,
        fromJson: (json) => json as List<dynamic>,
      );
      if (!response.success) {
        throw Exception(response.message);
      }
      if (response.data == null) return [];
      return response.data!
          .whereType<Map<String, dynamic>>()
          .map(CommissionSlab.fromJson)
          .toList();
    } catch (e, st) {
      AppLogger.error(
        'getActiveSlabs failed',
        tag: 'CommissionRepo',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<List<EarnedCommissionEntry>> getEarnedEntries({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from.toIso8601String();
      if (to != null) params['to'] = to.toIso8601String();

      final response = await apiClient.get<List<dynamic>>(
        ApiEndpoints.earnedCommission,
        queryParameters: params.isNotEmpty ? params : null,
        fromJson: (json) => json as List<dynamic>,
      );
      if (!response.success || response.data == null) return [];
      return response.data!
          .whereType<Map<String, dynamic>>()
          .map(EarnedCommissionEntry.fromJson)
          .toList();
    } catch (e, st) {
      AppLogger.error(
        'getEarnedEntries failed',
        tag: 'CommissionRepo',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }
}
