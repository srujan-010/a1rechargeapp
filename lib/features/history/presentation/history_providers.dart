import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/utils/logger.dart';
import '../../wallet/domain/models/wallet_transaction.dart';
import '../../dashboard/presentation/dashboard_providers.dart';

class HistoryTransactionsNotifier extends AsyncNotifier<List<WalletTransaction>> {
  @override
  FutureOr<List<WalletTransaction>> build() {
    final cache = LocalCacheService.instance;
    final cachedList = cache.get<List<dynamic>>(cache.historyBox, 'cached_statement');
    List<WalletTransaction>? cachedTxns;

    if (cachedList != null) {
      try {
        cachedTxns = cachedList
            .map((item) => WalletTransaction.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (e) {
        AppLogger.warning('Failed to parse cached statement history', tag: 'Cache');
      }
    }

    // Background network refresh
    _refreshInBackground();

    return cachedTxns ?? <WalletTransaction>[];
  }

  Future<void> _refreshInBackground() async {
    try {
      final userSession = ref.read(sessionProvider).valueOrNull;
      final repo = ref.read(walletRepositoryProvider);
      final result = await repo.getStatement(page: 1, pageSize: 50).timeout(const Duration(seconds: 5));
      final freshTxns = result.valueOrNull;

      AppLogger.info(
        '[HISTORY DEBUG]\n'
        'authenticatedUserId: ${userSession?.id ?? "authenticated_user"}\n'
        'endpoint: /wallet/statement\n'
        'HTTP status: ${result.isSuccess ? 200 : "ERROR"}\n'
        'raw transaction count: ${freshTxns?.length ?? 0}\n'
        'parsed transaction count: ${freshTxns?.length ?? 0}',
        tag: 'HISTORY_DEBUG',
      );

      if (freshTxns != null) {
        LocalCacheService.instance.put(
          LocalCacheService.instance.historyBox,
          'cached_statement',
          freshTxns.map((t) => t.toJson()).toList(),
        );
        state = AsyncData(freshTxns);
      }
    } catch (e) {
      AppLogger.warning('History statement background refresh error: $e', tag: 'HistoryProviders');
    }
  }

  Future<void> reload() async {
    await _refreshInBackground();
  }
}

final historyTransactionsProvider = AsyncNotifierProvider<HistoryTransactionsNotifier, List<WalletTransaction>>(
  HistoryTransactionsNotifier.new,
);
