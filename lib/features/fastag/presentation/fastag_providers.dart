import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../data/repository/fastag_repository.dart';
import '../data/services/fastag_api_service.dart';
import '../domain/models/fastag_models.dart';

final fastagApiServiceProvider = Provider<FastagApiService>((ref) {
  return FastagApiService(ref.watch(apiClientProvider));
});

final fastagRepositoryProvider = Provider<FastagRepository>((ref) {
  return FastagRepository(ref.watch(fastagApiServiceProvider));
});

final fastagOperatorsProvider = FutureProvider.autoDispose<List<FastagOperator>>((ref) {
  final repo = ref.watch(fastagRepositoryProvider);
  return repo.getOperators();
});
