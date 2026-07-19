import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../../recharge/domain/models/recharge_result.dart';
import 'models/insurance_models.dart';

abstract class InsuranceRepository {
  Future<Result<List<InsuranceProvider>, AppException>> getProviders();

  Future<Result<PolicyDetails, AppException>> fetchPolicyDetails({
    required InsuranceProvider provider,
    required String policyNumber,
    String? dob,
  });

  Future<Result<RechargeReceipt, AppException>> payPremium({
    required PolicyDetails policy,
    required String mpin,
  });
}
