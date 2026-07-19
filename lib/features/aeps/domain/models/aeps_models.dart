import 'package:equatable/equatable.dart';

enum AepsTransactionType {
  cashWithdrawal,
  balanceEnquiry,
  miniStatement,
  aadhaarPay
}

class Bank extends Equatable {
  const Bank({
    required this.id,
    required this.name,
    required this.iin, // Issuer Identification Number
    this.logoUrl,
  });

  final String id;
  final String name;
  final String iin;
  final String? logoUrl;

  @override
  List<Object?> get props => [id, name, iin];
}

class AepsResult extends Equatable {
  const AepsResult({
    required this.transactionId,
    required this.referenceId,
    required this.type,
    required this.status,
    required this.bankName,
    required this.aadhaarLast4,
    required this.timestamp,
    this.amountPaise,
    this.balancePaise,
    this.statementLines = const [],
    this.errorMessage,
  });

  final String transactionId;
  final String referenceId; // e.g., RRN (Retrieval Reference Number)
  final AepsTransactionType type;
  final bool status; // true for success, false for failure
  final String bankName;
  final String aadhaarLast4;
  final DateTime timestamp;
  
  // Specific to Cash Withdrawal and Aadhaar Pay
  final int? amountPaise;
  
  // Specific to Balance Enquiry and Statement
  final int? balancePaise;
  
  // Specific to Mini Statement
  final List<String> statementLines;

  final String? errorMessage;

  @override
  List<Object?> get props => [
        transactionId,
        referenceId,
        type,
        status,
        bankName,
        aadhaarLast4,
        amountPaise,
        balancePaise,
      ];
}
