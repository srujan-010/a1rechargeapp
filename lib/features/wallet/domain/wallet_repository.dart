// lib/features/wallet/domain/wallet_repository.dart
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import 'models/wallet_balance.dart';
import 'models/wallet_transaction.dart';

abstract class WalletRepository {
  Future<Result<WalletBalance, AppException>> getBalance();
  Future<Result<List<WalletTransaction>, AppException>> getStatement({
    int page = 1,
    int pageSize = 20,
    DateTime? from,
    DateTime? to,
  });
  Future<Result<List<WalletTransaction>, AppException>> getRecentTransactions({int limit = 5});
  Future<Result<Map<String, dynamic>, AppException>> getEarningsSummary();
  Future<Result<Map<String, dynamic>, AppException>> getDashboardAnalytics(String period);
  Future<Result<WalletBalance, AppException>> topup(int amountPaise);
}
