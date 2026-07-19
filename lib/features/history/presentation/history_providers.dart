import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../wallet/domain/models/wallet_transaction.dart';
import '../../dashboard/presentation/dashboard_providers.dart';

final historyTransactionsProvider = FutureProvider<List<WalletTransaction>>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  final result = await repo.getStatement(page: 1, pageSize: 50); // Fetch a decent chunk for history
  return result.getOrElseCompute((e) => throw e);
});
