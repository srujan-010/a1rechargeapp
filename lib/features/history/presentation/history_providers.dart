import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/utils/logger.dart';
import '../../wallet/domain/models/wallet_transaction.dart';
import '../../dashboard/presentation/dashboard_providers.dart';

class HistoryTransactionsNotifier extends AsyncNotifier<List<WalletTransaction>> {
  @override
  FutureOr<List<WalletTransaction>> build() async {
    final userSession = ref.read(sessionProvider).valueOrNull;
    final repo = ref.read(walletRepositoryProvider);

    try {
      final result = await repo.getStatement(page: 1, pageSize: 50).timeout(const Duration(seconds: 6));
      final freshTxns = result.valueOrNull;

      AppLogger.info(
        '[HISTORY DEBUG]\n'
        'authenticatedUserId: ${userSession?.id ?? "authenticated_user"}\n'
        'endpoint: /wallet/statement\n'
        'HTTP status: ${result.isSuccess ? 200 : "ERROR"}\n'
        'raw transaction count: ${freshTxns?.length ?? 0}\n'
        'parsed transaction count: ${freshTxns?.length ?? 0}\n'
        'filtered transaction count: ${freshTxns?.length ?? 0}',
        tag: 'HISTORY_DEBUG',
      );

      if (freshTxns != null) {
        LocalCacheService.instance.put(
          LocalCacheService.instance.historyBox,
          'cached_statement',
          freshTxns.map((t) => t.toJson()).toList(),
        );
        return freshTxns;
      }
    } catch (e) {
      AppLogger.warning('History statement fetch error: $e', tag: 'HistoryProviders');
    }

    // Fallback to cache if network call fails/times out
    final cache = LocalCacheService.instance;
    final cachedList = cache.get<List<dynamic>>(cache.historyBox, 'cached_statement');
    if (cachedList != null) {
      try {
        return cachedList
            .map((item) => WalletTransaction.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (e) {
        AppLogger.warning('Failed to parse cached statement history', tag: 'Cache');
      }
    }

    return <WalletTransaction>[];
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}

final historyTransactionsProvider = AsyncNotifierProvider<HistoryTransactionsNotifier, List<WalletTransaction>>(
  HistoryTransactionsNotifier.new,
);
