import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import 'models/dmt_models.dart';

abstract class DmtRepository {
  /// Fetches a remitter by mobile number. Returns null (inside Success) if not found.
  Future<Result<Remitter?, AppException>> getRemitter(String mobileNumber);

  /// Registers a new remitter.
  Future<Result<Remitter, AppException>> registerRemitter({
    required String mobileNumber,
    required String name,
    required String otp,
  });

  /// Fetches beneficiaries for a given remitter ID.
  Future<Result<List<Beneficiary>, AppException>> getBeneficiaries(String remitterId);

  /// Adds a new beneficiary to a remitter's account.
  Future<Result<Beneficiary, AppException>> addBeneficiary({
    required String remitterId,
    required String accountNumber,
    required String ifscCode,
    required String name,
    required String bankName,
  });

  /// Processes a DMT transaction.
  Future<Result<DmtResult, AppException>> processTransfer({
    required String remitterId,
    required String beneficiaryId,
    required int amountPaise,
    required DmtTransferMode mode,
    required String mpin,
  });
}
