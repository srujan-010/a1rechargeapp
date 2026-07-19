// lib/features/wallet/data/wallet_repository_mock.dart
import 'dart:math';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../domain/wallet_repository.dart';
import '../domain/models/wallet_balance.dart';
import '../domain/models/wallet_transaction.dart';

class WalletRepositoryMock implements WalletRepository {
  final _random = Random();

  Future<void> _delay() async {
    final ms = AppConfig.mockLatencyMin.inMilliseconds +
        _random.nextInt(AppConfig.mockLatencyMax.inMilliseconds - AppConfig.mockLatencyMin.inMilliseconds);
    await Future.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<Result<WalletBalance, AppException>> getBalance() async {
    await _delay();
    return Success(WalletBalance.fake());
  }

  @override
  Future<Result<List<WalletTransaction>, AppException>> getStatement({
    int page = 1, int pageSize = 20, DateTime? from, DateTime? to,
  }) async {
    await _delay();
    return Success(WalletTransaction.fakeList(count: pageSize));
  }

  @override
  Future<Result<List<WalletTransaction>, AppException>> getRecentTransactions({int limit = 5}) async {
    await _delay();
    return Success(WalletTransaction.fakeList(count: limit));
  }

  @override
  Future<Result<Map<String, dynamic>, AppException>> getEarningsSummary() async {
    await _delay();
    return const Success({
      'todayEarningsPaise': 125000,   // ₹1,250
      'todayTransactions': 23,
      'todayCommissionPaise': 8750,   // ₹87.50
      'monthlyEarningsPaise': 2750000, // ₹27,500
    });
  }

  @override
  Future<Result<Map<String, dynamic>, AppException>> getDashboardAnalytics(String period) async {
    await _delay();
    return const Success({
      'currentPeriod': {
        'commission': 5000,
        'recharge': 150000,
        'transactions': 12,
      },
      'previousPeriod': {
        'commission': 4000,
        'recharge': 120000,
        'transactions': 10,
      }
    });
  }

  @override
  Future<Result<WalletBalance, AppException>> topup(int amountPaise) async {
    await _delay();
    final balance = WalletBalance(
      availablePaise: 1254000,
      ledgerBalancePaise: 1254000,
      onHoldPaise: 0,
      pendingSettlementPaise: 0,
      lastUpdated: DateTime.now(),
      walletId: 'RET000001',
    );
    return Success(balance);
  }
}
