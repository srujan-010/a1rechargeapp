import 'dart:math';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../domain/aeps_repository.dart';
import '../domain/models/aeps_models.dart';

class AepsRepositoryMock implements AepsRepository {
  final _random = Random();

  Future<void> _delay() async {
    final ms = AppConfig.mockLatencyMin.inMilliseconds +
        _random.nextInt(AppConfig.mockLatencyMax.inMilliseconds - AppConfig.mockLatencyMin.inMilliseconds);
    // Add extra delay for AEPS to simulate biometric validation
    await Future.delayed(Duration(milliseconds: ms + 1500));
  }

  @override
  Future<Result<List<Bank>, AppException>> getBanks() async {
    await _delay();
    return const Success([
      Bank(id: 'sbi', name: 'State Bank of India', iin: '607152'),
      Bank(id: 'pnb', name: 'Punjab National Bank', iin: '607153'),
      Bank(id: 'bob', name: 'Bank of Baroda', iin: '607154'),
      Bank(id: 'hdfc', name: 'HDFC Bank', iin: '607155'),
      Bank(id: 'icici', name: 'ICICI Bank', iin: '607156'),
      Bank(id: 'axis', name: 'Axis Bank', iin: '607157'),
      Bank(id: 'ubi', name: 'Union Bank of India', iin: '607158'),
      Bank(id: 'cbi', name: 'Central Bank of India', iin: '607159'),
    ]);
  }

  @override
  Future<Result<AepsResult, AppException>> performTransaction({
    required AepsTransactionType type,
    required Bank bank,
    required String aadhaarNumber,
    int? amountPaise,
  }) async {
    await _delay();

    // Simulate failure cases (e.g., specific aadhaar triggers error)
    if (aadhaarNumber.endsWith('0000')) {
      return const Failure(TransactionException(
        message: 'Aadhaar authentication failed. Please try again.',
        code: 'BIOMETRIC_MISMATCH',
      ));
    }
    if (aadhaarNumber.endsWith('1111') && 
       (type == AepsTransactionType.cashWithdrawal || type == AepsTransactionType.aadhaarPay)) {
      return const Failure(TransactionException(
        message: 'Insufficient balance in the selected bank account.',
        code: 'INSUFFICIENT_FUNDS',
      ));
    }

    final aadhaarLast4 = aadhaarNumber.substring(aadhaarNumber.length - 4);
    final txId = 'AEPS${_random.nextInt(999999999).toString().padLeft(9, '0')}';
    final rrn = _random.nextInt(999999999999).toString().padLeft(12, '0');
    
    // Base balance for mock
    int baseBalancePaise = (1500 + _random.nextInt(10000)) * 100;

    switch (type) {
      case AepsTransactionType.cashWithdrawal:
      case AepsTransactionType.aadhaarPay:
        if (amountPaise == null || amountPaise <= 0) {
          return const Failure(ValidationException(message: 'Invalid amount'));
        }
        return Success(AepsResult(
          transactionId: txId,
          referenceId: rrn,
          type: type,
          status: true,
          bankName: bank.name,
          aadhaarLast4: aadhaarLast4,
          timestamp: DateTime.now(),
          amountPaise: amountPaise,
          balancePaise: baseBalancePaise - amountPaise,
        ));
      
      case AepsTransactionType.balanceEnquiry:
        return Success(AepsResult(
          transactionId: txId,
          referenceId: rrn,
          type: type,
          status: true,
          bankName: bank.name,
          aadhaarLast4: aadhaarLast4,
          timestamp: DateTime.now(),
          balancePaise: baseBalancePaise,
        ));
        
      case AepsTransactionType.miniStatement:
        return Success(AepsResult(
          transactionId: txId,
          referenceId: rrn,
          type: type,
          status: true,
          bankName: bank.name,
          aadhaarLast4: aadhaarLast4,
          timestamp: DateTime.now(),
          balancePaise: baseBalancePaise,
          statementLines: [
            '2023-10-01: UPI/Transfer - ₹500.00 (Dr)',
            '2023-10-02: NEFT/Salary - ₹25000.00 (Cr)',
            '2023-10-05: ATM WDL - ₹2000.00 (Dr)',
            '2023-10-08: POS/Retail - ₹1250.00 (Dr)',
          ],
        ));
    }
  }
}
