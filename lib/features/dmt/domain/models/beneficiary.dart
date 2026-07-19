// lib/features/dmt/domain/models/beneficiary.dart
import 'package:equatable/equatable.dart';

enum BeneficiaryVerificationStatus { unverified, pending, verified, failed }

class Beneficiary extends Equatable {
  const Beneficiary({
    required this.id,
    required this.name,
    required this.accountNumber,
    required this.ifsc,
    required this.bankName,
    required this.verificationStatus,
    this.branchName,
    this.upiId,
    this.createdAt,
  });

  final String id;
  final String name;
  final String accountNumber;
  final String ifsc;
  final String bankName;
  final BeneficiaryVerificationStatus verificationStatus;
  final String? branchName;
  final String? upiId;
  final DateTime? createdAt;

  bool get isVerified =>
      verificationStatus == BeneficiaryVerificationStatus.verified;

  /// Masked account number for display: ****1234
  String get maskedAccount {
    if (accountNumber.length <= 4) return '****';
    return '****${accountNumber.substring(accountNumber.length - 4)}';
  }

  factory Beneficiary.fromJson(Map<String, dynamic> json) => Beneficiary(
        id: json['id'] as String? ?? json['_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
        ifsc: json['ifsc'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        verificationStatus:
            _parseStatus(json['verificationStatus'] as String?),
        branchName: json['branchName'] as String?,
        upiId: json['upiId'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'accountNumber': accountNumber,
        'ifsc': ifsc,
        'bankName': bankName,
        'verificationStatus': verificationStatus.name,
        'branchName': branchName,
        'upiId': upiId,
        'createdAt': createdAt?.toIso8601String(),
      };

  static BeneficiaryVerificationStatus _parseStatus(String? raw) =>
      switch (raw) {
        'verified' => BeneficiaryVerificationStatus.verified,
        'pending' => BeneficiaryVerificationStatus.pending,
        'failed' => BeneficiaryVerificationStatus.failed,
        _ => BeneficiaryVerificationStatus.unverified,
      };

  factory Beneficiary.fake() => const Beneficiary(
        id: 'BEN001',
        name: 'Suresh Babu',
        accountNumber: '123456789012',
        ifsc: 'SBIN0001234',
        bankName: 'State Bank of India',
        verificationStatus: BeneficiaryVerificationStatus.verified,
        branchName: 'Guntur Main Branch',
      );

  @override
  List<Object?> get props =>
      [id, name, accountNumber, ifsc, verificationStatus];
}
