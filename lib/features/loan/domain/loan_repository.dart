import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../../recharge/domain/models/recharge_result.dart';
import 'models/loan_models.dart';

abstract class LoanRepository {
  Future<Result<List<LoanProvider>, AppException>> getProviders();

  Future<Result<LoanDetails, AppException>> fetchLoanDetails({
    required LoanProvider provider,
    required String loanAccountNumber,
  });

  Future<Result<RechargeReceipt, AppException>> payEmi({
    required LoanDetails loan,
    required String mpin,
  });
}
