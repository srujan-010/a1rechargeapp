import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/utils/logger.dart';
import '../../../features/wallet/data/wallet_repository_mock.dart';
import '../../../features/wallet/data/wallet_repository_impl.dart';
import '../../../features/wallet/domain/wallet_repository.dart';
import '../../../features/wallet/domain/models/wallet_balance.dart';
import '../../../features/wallet/domain/models/wallet_transaction.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  if (AppConfig.useMockApi) {
    return WalletRepositoryMock();
  } else {
    return WalletRepositoryImpl(apiClient: ref.watch(apiClientProvider));
  }
});

/// Non-Blocking Stale-While-Revalidate Wallet Balance Provider
class WalletBalanceNotifier extends AsyncNotifier<WalletBalance> {
  @override
  FutureOr<WalletBalance> build() {
    final cache = LocalCacheService.instance;
    final cachedMap = cache.get<Map<dynamic, dynamic>>(cache.walletBox, 'cached_balance');
    WalletBalance? cachedBalance;
    if (cachedMap != null) {
      try {
        cachedBalance = WalletBalance.fromJson(Map<String, dynamic>.from(cachedMap));
      } catch (e) {
        AppLogger.warning('Failed to parse cached wallet balance', tag: 'Cache');
      }
    }

    // Trigger non-blocking background network refresh
    _refreshInBackground();

    // Immediately return cached balance if present, or zero initial balance
    return cachedBalance ?? WalletBalance.zero();
  }

  Future<void> _refreshInBackground() async {
    try {
      final repo = ref.read(walletRepositoryProvider);
      final result = await repo.getBalance().timeout(const Duration(seconds: 3));
      final freshBalance = result.valueOrNull;
      if (freshBalance != null) {
        LocalCacheService.instance.put(
          LocalCacheService.instance.walletBox,
          'cached_balance',
          freshBalance.toJson(),
        );
        state = AsyncData(freshBalance);
      }
    } catch (e) {
      AppLogger.warning('Wallet balance background refresh error: $e', tag: 'DashboardProviders');
    }
  }
}

final walletBalanceProvider = AsyncNotifierProvider<WalletBalanceNotifier, WalletBalance>(
  WalletBalanceNotifier.new,
);

/// Non-Blocking Stale-While-Revalidate Recent Transactions Provider
class RecentTransactionsNotifier extends AsyncNotifier<List<WalletTransaction>> {
  @override
  FutureOr<List<WalletTransaction>> build() {
    final cache = LocalCacheService.instance;
    final cachedList = cache.get<List<dynamic>>(cache.walletBox, 'cached_recent_txns');
    List<WalletTransaction>? cachedTxns;
    if (cachedList != null) {
      try {
        cachedTxns = cachedList
            .map((item) => WalletTransaction.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (e) {
        AppLogger.warning('Failed to parse cached recent transactions', tag: 'Cache');
      }
    }

    _refreshInBackground();

    return cachedTxns ?? <WalletTransaction>[];
  }

  Future<void> _refreshInBackground() async {
    try {
      final repo = ref.read(walletRepositoryProvider);
      final result = await repo.getRecentTransactions(limit: 5).timeout(const Duration(seconds: 3));
      final freshTxns = result.valueOrNull;
      if (freshTxns != null) {
        LocalCacheService.instance.put(
          LocalCacheService.instance.walletBox,
          'cached_recent_txns',
          freshTxns.map((t) => t.toJson()).toList(),
        );
        state = AsyncData(freshTxns);
      }
    } catch (e) {
      AppLogger.warning('Recent txns background refresh error: $e', tag: 'DashboardProviders');
    }
  }
}

final recentTransactionsProvider = AsyncNotifierProvider<RecentTransactionsNotifier, List<WalletTransaction>>(
  RecentTransactionsNotifier.new,
);

/// Non-Blocking Stale-While-Revalidate Earnings Summary Provider
class EarningsSummaryNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  FutureOr<Map<String, dynamic>> build() {
    final cache = LocalCacheService.instance;
    final cachedMap = cache.get<Map<dynamic, dynamic>>(cache.dashboardBox, 'cached_summary');
    Map<String, dynamic>? cachedSummary;
    if (cachedMap != null) {
      try {
        cachedSummary = Map<String, dynamic>.from(cachedMap);
      } catch (_) {}
    }

    _refreshInBackground();

    return cachedSummary ?? {
      'todayRechargeAmountPaise': 0,
      'todayTransactions': 0,
      'todayCommissionPaise': 0,
      'successfulTransactions': 0,
      'failedTransactions': 0,
      'pendingTransactions': 0,
    };
  }

  Future<void> _refreshInBackground() async {
    try {
      final repo = ref.read(walletRepositoryProvider);
      final result = await repo.getEarningsSummary().timeout(const Duration(seconds: 3));
      final freshSummary = result.valueOrNull;
      if (freshSummary != null) {
        LocalCacheService.instance.put(
          LocalCacheService.instance.dashboardBox,
          'cached_summary',
          freshSummary,
        );
        state = AsyncData(freshSummary);
      }
    } catch (e) {
      AppLogger.warning('Earnings summary background refresh error: $e', tag: 'DashboardProviders');
    }
  }
}

final earningsSummaryProvider = AsyncNotifierProvider<EarningsSummaryNotifier, Map<String, dynamic>>(
  EarningsSummaryNotifier.new,
);

final dashboardAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final repo = ref.watch(walletRepositoryProvider);
  final result = await repo.getDashboardAnalytics(period).timeout(const Duration(seconds: 3));
  return result.getOrElseCompute((e) => throw e);
});

// Dashboard refresh — pull-to-refresh triggers this
class DashboardRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() {
    state++;
  }
}

final dashboardRefreshProvider = NotifierProvider<DashboardRefreshNotifier, int>(
  DashboardRefreshNotifier.new,
);
