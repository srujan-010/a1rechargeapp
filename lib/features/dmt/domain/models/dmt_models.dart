import 'package:equatable/equatable.dart';

class Remitter extends Equatable {
  const Remitter({
    required this.id,
    required this.mobileNumber,
    required this.name,
    required this.availableLimitPaise,
    required this.totalLimitPaise,
    this.isKycDone = false,
  });

  final String id;
  final String mobileNumber;
  final String name;
  final int availableLimitPaise;
  final int totalLimitPaise;
  final bool isKycDone;

  @override
  List<Object?> get props => [id, mobileNumber, name, availableLimitPaise];
}

class Beneficiary extends Equatable {
  const Beneficiary({
    required this.id,
    required this.remitterId,
    required this.name,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    this.isVerified = false,
  });

  final String id;
  final String remitterId;
  final String name;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final bool isVerified;

  @override
  List<Object?> get props => [id, remitterId, accountNumber, ifscCode];
}

enum DmtTransferMode { imps, neft }

class DmtResult extends Equatable {
  const DmtResult({
    required this.transactionId,
    required this.referenceId, // UTR Number
    required this.beneficiaryName,
    required this.accountNumber,
    required this.amountPaise,
    required this.mode,
    required this.status,
    required this.timestamp,
    this.errorMessage,
  });

  final String transactionId;
  final String referenceId; // Bank UTR
  final String beneficiaryName;
  final String accountNumber;
  final int amountPaise;
  final DmtTransferMode mode;
  final bool status;
  final DateTime timestamp;
  final String? errorMessage;

  @override
  List<Object?> get props => [transactionId, referenceId, amountPaise, status];
}
