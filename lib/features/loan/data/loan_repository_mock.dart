import 'dart:math';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../domain/loan_repository.dart';
import '../domain/models/loan_models.dart';

class LoanRepositoryMock implements LoanRepository {
  final _random = Random();

  Future<void> _delay() async {
    final ms = AppConfig.mockLatencyMin.inMilliseconds +
        _random.nextInt(AppConfig.mockLatencyMax.inMilliseconds - AppConfig.mockLatencyMin.inMilliseconds);
    await Future.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<Result<List<LoanProvider>, AppException>> getProviders() async {
    await _delay();
    return const Success([
      LoanProvider(id: 'bajaj_finance', name: 'Bajaj Finance'),
      LoanProvider(id: 'muthoot', name: 'Muthoot Finance'),
      LoanProvider(id: 'hdb', name: 'HDB Financial Services'),
      LoanProvider(id: 'cholamandalam', name: 'Cholamandalam Investment'),
      LoanProvider(id: 'manappuram', name: 'Manappuram Finance'),
      LoanProvider(id: 'shriram', name: 'Shriram Finance'),
    ]);
  }

  @override
  Future<Result<LoanDetails, AppException>> fetchLoanDetails({
    required LoanProvider provider,
    required String loanAccountNumber,
  }) async {
    await _delay();

    if (loanAccountNumber.length < 5) {
      return const Failure(ValidationException(message: 'Invalid Loan Account Number'));
    }

    return Success(LoanDetails(
      loanAccountNumber: loanAccountNumber,
      customerName: 'Ravi Kumar',
      providerName: provider.name,
      emiAmountPaise: (2000 + _random.nextInt(20000)) * 100,
      dueDate: DateTime.now().add(Duration(days: _random.nextInt(30))),
    ));
  }

  @override
  Future<Result<RechargeReceipt, AppException>> payEmi({
    required LoanDetails loan,
    required String mpin,
  }) async {
    await _delay();

    if (mpin != '123456') {
      return const Failure(AuthException.invalidMpin);
    }

    final txId = 'EMI${_random.nextInt(999999999).toString().padLeft(9, '0')}';
    
    return Success(RechargeReceipt(
      transactionId: txId,
      referenceId: txId,
      status: RechargeStatus.success,
      amountPaise: loan.emiAmountPaise,
      timestamp: DateTime.now(),
      operatorName: loan.providerName,
      mobileNumber: loan.loanAccountNumber,
    ));
  }
}
