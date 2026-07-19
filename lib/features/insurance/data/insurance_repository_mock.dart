import 'dart:math';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../domain/insurance_repository.dart';
import '../domain/models/insurance_models.dart';

class InsuranceRepositoryMock implements InsuranceRepository {
  final _random = Random();

  Future<void> _delay() async {
    final ms = AppConfig.mockLatencyMin.inMilliseconds +
        _random.nextInt(AppConfig.mockLatencyMax.inMilliseconds - AppConfig.mockLatencyMin.inMilliseconds);
    await Future.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<Result<List<InsuranceProvider>, AppException>> getProviders() async {
    await _delay();
    return const Success([
      InsuranceProvider(id: 'lic', name: 'Life Insurance Corporation of India (LIC)', requiresDob: true),
      InsuranceProvider(id: 'sbi_life', name: 'SBI Life Insurance'),
      InsuranceProvider(id: 'hdfc_life', name: 'HDFC Life Insurance', requiresDob: true),
      InsuranceProvider(id: 'icici_pru', name: 'ICICI Prudential Life Insurance'),
      InsuranceProvider(id: 'max_life', name: 'Max Life Insurance'),
      InsuranceProvider(id: 'bajaj_allianz', name: 'Bajaj Allianz Life Insurance'),
    ]);
  }

  @override
  Future<Result<PolicyDetails, AppException>> fetchPolicyDetails({
    required InsuranceProvider provider,
    required String policyNumber,
    String? dob,
  }) async {
    await _delay();

    if (policyNumber.length < 6) {
      return const Failure(ValidationException(message: 'Invalid Policy Number'));
    }

    if (provider.requiresDob && (dob == null || dob.isEmpty)) {
      return const Failure(ValidationException(message: 'Date of Birth is required for this provider'));
    }

    return Success(PolicyDetails(
      policyNumber: policyNumber,
      customerName: 'Anjali Sharma',
      providerName: provider.name,
      premiumAmountPaise: (1500 + _random.nextInt(10000)) * 100,
      dueDate: DateTime.now().add(Duration(days: _random.nextInt(30))),
    ));
  }

  @override
  Future<Result<RechargeReceipt, AppException>> payPremium({
    required PolicyDetails policy,
    required String mpin,
  }) async {
    await _delay();

    if (mpin != '123456') {
      return const Failure(AuthException.invalidMpin);
    }

    final txId = 'INS${_random.nextInt(999999999).toString().padLeft(9, '0')}';
    
    return Success(RechargeReceipt(
      transactionId: txId,
      referenceId: txId,
      status: RechargeStatus.success,
      amountPaise: policy.premiumAmountPaise,
      timestamp: DateTime.now(),
      operatorName: policy.providerName,
      mobileNumber: policy.policyNumber,
    ));
  }
}
