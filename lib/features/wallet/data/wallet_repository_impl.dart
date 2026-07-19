// lib/features/wallet/data/wallet_repository_impl.dart
import '../../../core/models/app_exception.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/result.dart';
import '../domain/models/wallet_balance.dart';
import '../domain/models/wallet_transaction.dart';
import '../domain/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<Result<WalletBalance, AppException>> getBalance() async {
    try {
      final response = await apiClient.get<WalletBalance>(
        '/wallet/balance',
        fromJson: (json) => WalletBalance.fromJson(json as Map<String, dynamic>),
      );
      if (!response.success || response.data == null) {
        return Failure(ServerException(message: response.message));
      }
      return Success(response.data!);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e, st) {
      AppLogger.error('getBalance failed', tag: 'WalletRepo', error: e, stackTrace: st);
      return Failure(UnknownException.from(e));
    }
  }

  @override
  Future<Result<List<WalletTransaction>, AppException>> getStatement({
    int page = 1,
    int pageSize = 20,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'limit': pageSize,
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      };
      final response = await apiClient.get<List<WalletTransaction>>(
        '/wallet/statement',
        queryParameters: queryParams,
        fromJson: (json) {
          final list = json as List<dynamic>? ?? [];
          return list
              .map((item) => WalletTransaction.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
      if (!response.success || response.data == null) {
        return Failure(ServerException(message: response.message));
      }
      return Success(response.data!);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e, st) {
      AppLogger.error('getStatement failed', tag: 'WalletRepo', error: e, stackTrace: st);
      return Failure(UnknownException.from(e));
    }
  }

  @override
  Future<Result<List<WalletTransaction>, AppException>> getRecentTransactions({int limit = 5}) async {
    return getStatement(page: 1, pageSize: limit);
  }

  @override
  Future<Result<Map<String, dynamic>, AppException>> getEarningsSummary() async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/wallet/summary',
        fromJson: (json) => json as Map<String, dynamic>,
      );
      if (!response.success || response.data == null) {
        return Failure(ServerException(message: response.message));
      }
      
      final data = response.data!;
      return Success({
        'todayRechargeAmountPaise': data['todayRechargeAmount'] as int? ?? 0,
        'todayTransactions': data['todayTransactions'] as int? ?? 0,
        'todayCommissionPaise': data['todayCommission'] as int? ?? 0,
        'successfulTransactions': data['successfulTransactions'] as int? ?? 0,
        'failedTransactions': data['failedTransactions'] as int? ?? 0,
        'pendingTransactions': data['pendingTransactions'] as int? ?? 0,
      });
    } catch (e, st) {
      AppLogger.error('getEarningsSummary failed', tag: 'WalletRepo', error: e, stackTrace: st);
      return Failure(UnknownException.from(e));
    }
  }

  @override
  Future<Result<Map<String, dynamic>, AppException>> getDashboardAnalytics(String period) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/wallet/analytics',
        queryParameters: {'period': period},
        fromJson: (json) => json as Map<String, dynamic>,
      );
      if (!response.success || response.data == null) {
        return Failure(ServerException(message: response.message));
      }
      return Success(response.data!);
    } catch (e, st) {
      AppLogger.error('getDashboardAnalytics failed', tag: 'WalletRepo', error: e, stackTrace: st);
      return Failure(UnknownException.from(e));
    }
  }

  @override
  Future<Result<WalletBalance, AppException>> topup(int amountPaise) async {
    try {
      final response = await apiClient.post<WalletBalance>(
        '/wallet/topup',
        data: {'amountPaise': amountPaise},
        fromJson: (json) => WalletBalance.fromJson(json as Map<String, dynamic>),
      );
      if (!response.success || response.data == null) {
        return Failure(ServerException(message: response.message));
      }
      return Success(response.data!);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e, st) {
      AppLogger.error('topup failed', tag: 'WalletRepo', error: e, stackTrace: st);
      return Failure(UnknownException.from(e));
    }
  }
}
