import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import 'models/aeps_models.dart';

abstract class AepsRepository {
  /// Fetches the list of supported banks for AEPS.
  Future<Result<List<Bank>, AppException>> getBanks();

  /// Performs an AEPS transaction (mocking the biometric capture flow inside).
  Future<Result<AepsResult, AppException>> performTransaction({
    required AepsTransactionType type,
    required Bank bank,
    required String aadhaarNumber,
    int? amountPaise,
  });
}
