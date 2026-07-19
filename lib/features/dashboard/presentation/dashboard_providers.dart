import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
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

final walletBalanceProvider = FutureProvider<WalletBalance>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  final result = await repo.getBalance();
  return result.getOrElseCompute((e) => throw e);
});

final recentTransactionsProvider = FutureProvider<List<WalletTransaction>>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  final result = await repo.getRecentTransactions(limit: 5);
  return result.getOrElseCompute((e) => throw e);
});

final earningsSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  final result = await repo.getEarningsSummary();
  return result.getOrElseCompute((e) => throw e);
});

final dashboardAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final repo = ref.watch(walletRepositoryProvider);
  final result = await repo.getDashboardAnalytics(period);
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
