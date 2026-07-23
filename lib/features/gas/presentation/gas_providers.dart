import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../data/repository/gas_repository.dart';
import '../data/services/gas_api_service.dart';
import '../domain/models/gas_models.dart';

final gasApiServiceProvider = Provider<GasApiService>((ref) {
  return GasApiService(ref.watch(apiClientProvider));
});

final gasRepositoryProvider = Provider<GasRepository>((ref) {
  return GasRepository(ref.watch(gasApiServiceProvider));
});

final gasOperatorsProvider = FutureProvider.autoDispose<List<GasOperator>>((ref) {
  final repo = ref.watch(gasRepositoryProvider);
  return repo.getOperators();
});
