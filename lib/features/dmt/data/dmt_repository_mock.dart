import 'dart:math';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../domain/dmt_repository.dart';
import '../domain/models/dmt_models.dart';

class DmtRepositoryMock implements DmtRepository {
  final _random = Random();
  
  // In-memory mock storage
  final Map<String, Remitter> _remitters = {
    '9876543210': const Remitter(
      id: 'rem_1',
      mobileNumber: '9876543210',
      name: 'John Doe',
      availableLimitPaise: 2500000, // 25,000 INR
      totalLimitPaise: 2500000,
      isKycDone: true,
    ),
  };

  final Map<String, List<Beneficiary>> _beneficiaries = {
    'rem_1': [
      const Beneficiary(
        id: 'ben_1',
        remitterId: 'rem_1',
        name: 'Jane Smith',
        accountNumber: 'XXXXX4321',
        ifscCode: 'SBIN0001234',
        bankName: 'State Bank of India',
        isVerified: true,
      ),
      const Beneficiary(
        id: 'ben_2',
        remitterId: 'rem_1',
        name: 'Rahul Sharma',
        accountNumber: 'XXXXX9876',
        ifscCode: 'HDFC0004321',
        bankName: 'HDFC Bank',
        isVerified: false,
      ),
    ],
  };

  Future<void> _delay() async {
    final ms = AppConfig.mockLatencyMin.inMilliseconds +
        _random.nextInt(AppConfig.mockLatencyMax.inMilliseconds - AppConfig.mockLatencyMin.inMilliseconds);
    await Future.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<Result<Remitter?, AppException>> getRemitter(String mobileNumber) async {
    await _delay();
    return Success(_remitters[mobileNumber]);
  }

  @override
  Future<Result<Remitter, AppException>> registerRemitter({
    required String mobileNumber,
    required String name,
    required String otp,
  }) async {
    await _delay();
    
    if (otp != '123456') {
      return const Failure(AuthException(message: 'Invalid OTP', code: 'INVALID_OTP'));
    }

    final newRemitter = Remitter(
      id: 'rem_${_random.nextInt(9999)}',
      mobileNumber: mobileNumber,
      name: name,
      availableLimitPaise: 2500000, // Base limit for non-KYC is usually 25k
      totalLimitPaise: 2500000,
    );
    
    _remitters[mobileNumber] = newRemitter;
    _beneficiaries[newRemitter.id] = [];
    
    return Success(newRemitter);
  }

  @override
  Future<Result<List<Beneficiary>, AppException>> getBeneficiaries(String remitterId) async {
    await _delay();
    return Success(_beneficiaries[remitterId] ?? []);
  }

  @override
  Future<Result<Beneficiary, AppException>> addBeneficiary({
    required String remitterId,
    required String accountNumber,
    required String ifscCode,
    required String name,
    required String bankName,
  }) async {
    await _delay();
    
    final newBen = Beneficiary(
      id: 'ben_${_random.nextInt(9999)}',
      remitterId: remitterId,
      name: name,
      accountNumber: 'XXXXX${accountNumber.length > 4 ? accountNumber.substring(accountNumber.length - 4) : accountNumber}',
      ifscCode: ifscCode,
      bankName: bankName,
      isVerified: false,
    );
    
    if (!_beneficiaries.containsKey(remitterId)) {
      _beneficiaries[remitterId] = [];
    }
    _beneficiaries[remitterId]!.add(newBen);
    
    return Success(newBen);
  }

  @override
  Future<Result<DmtResult, AppException>> processTransfer({
    required String remitterId,
    required String beneficiaryId,
    required int amountPaise,
    required DmtTransferMode mode,
    required String mpin,
  }) async {
    await _delay();
    
    if (mpin != '123456') {
      return const Failure(AuthException.invalidMpin);
    }
    
    // Find remitter to check limits
    final remitter = _remitters.values.firstWhere((r) => r.id == remitterId);
    if (remitter.availableLimitPaise < amountPaise) {
      return const Failure(TransactionException(
        message: 'Transaction amount exceeds available remitter limit.',
        code: 'LIMIT_EXCEEDED',
      ));
    }
    
    // Find beneficiary
    final bens = _beneficiaries[remitterId] ?? [];
    final beneficiary = bens.firstWhere((b) => b.id == beneficiaryId);

    // Update remitter limit
    final updatedRemitter = Remitter(
      id: remitter.id,
      mobileNumber: remitter.mobileNumber,
      name: remitter.name,
      availableLimitPaise: remitter.availableLimitPaise - amountPaise,
      totalLimitPaise: remitter.totalLimitPaise,
      isKycDone: remitter.isKycDone,
    );
    _remitters[remitter.mobileNumber] = updatedRemitter;

    final txId = 'DMT${_random.nextInt(999999999).toString().padLeft(9, '0')}';
    final utr = _random.nextInt(999999999999).toString().padLeft(12, '0');

    return Success(DmtResult(
      transactionId: txId,
      referenceId: utr,
      beneficiaryName: beneficiary.name,
      accountNumber: beneficiary.accountNumber,
      amountPaise: amountPaise,
      mode: mode,
      status: true,
      timestamp: DateTime.now(),
    ));
  }
}
