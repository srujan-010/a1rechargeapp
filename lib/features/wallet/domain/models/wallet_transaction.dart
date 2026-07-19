// lib/features/wallet/domain/models/wallet_transaction.dart
import 'package:equatable/equatable.dart';

enum TransactionType { credit, debit }
enum TransactionStatus { success, pending, failed, reversed }

class WalletTransaction extends Equatable {
  const WalletTransaction({
    required this.id,
    required this.status,
    required this.serviceType,
    required this.transactionTitle,
    required this.operatorName,
    required this.customerIdentifier,
    required this.amountPaise,
    required this.commissionEarnedPaise,
    required this.createdAt,
    required this.completedAt,
    required this.paymentMethod,
    required this.referenceId,
    this.apiReference,
    this.description,
    this.closingBalancePaise,
  });

  final String id;
  final String serviceType;
  final String operatorName;
  final String transactionTitle;
  final String customerIdentifier;
  final int amountPaise;
  final int commissionEarnedPaise;
  final TransactionStatus status;
  final DateTime createdAt;
  final DateTime completedAt;
  final String paymentMethod;
  final String referenceId;
  final String? apiReference;
  final String? description;
  final int? closingBalancePaise;

  // We infer credit/debit conceptually from service type or amount sign, 
  // but let's assume if it's commission or topup it's a credit, otherwise debit.
  bool get isCredit => serviceType == 'wallet_topup' || serviceType == 'commission';
  bool get isDebit => !isCredit;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    // Parse UTC and convert directly to IST (+5:30)
    DateTime parseToIST(String? isoString) {
      if (isoString == null) return DateTime.now();
      final utc = DateTime.parse(isoString).toUtc();
      return utc.add(const Duration(hours: 5, minutes: 30));
    }

    return WalletTransaction(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      serviceType: json['serviceType'] as String? ?? json['service'] as String? ?? 'unknown',
      operatorName: json['operatorName'] as String? ?? '',
      transactionTitle: json['transactionTitle'] as String? ?? 'Transaction',
      customerIdentifier: json['customerIdentifier'] as String? ?? json['mobileNumber'] as String? ?? '',
      amountPaise: (json['amount'] as num?)?.toInt() ?? (json['amountPaise'] as num?)?.toInt() ?? 0,
      commissionEarnedPaise: (json['commission'] as num?)?.toInt() ?? (json['commissionEarnedPaise'] as num?)?.toInt() ?? 0,
      status: _parseStatus(json['status'] as String?),
      createdAt: parseToIST(json['createdAt'] as String? ?? json['timestamp'] as String?),
      completedAt: parseToIST(json['completedAt'] as String? ?? json['timestamp'] as String?),
      paymentMethod: json['paymentMethod'] as String? ?? 'wallet',
      referenceId: json['referenceNumber'] as String? ?? json['referenceId'] as String? ?? '',
      apiReference: json['apiReference'] as String?,
      description: json['description'] as String?,
      closingBalancePaise: (json['closingBalancePaise'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceType': serviceType,
        'operatorName': operatorName,
        'transactionTitle': transactionTitle,
        'customerIdentifier': customerIdentifier,
        'amount': amountPaise,
        'commission': commissionEarnedPaise,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'completedAt': completedAt.toUtc().toIso8601String(),
        'paymentMethod': paymentMethod,
        'referenceNumber': referenceId,
        'apiReference': apiReference,
        'description': description,
        'closingBalancePaise': closingBalancePaise,
      };

  static TransactionStatus _parseStatus(String? raw) => switch (raw) {
        'success' => TransactionStatus.success,
        'pending' => TransactionStatus.pending,
        'failed' => TransactionStatus.failed,
        'reversed' => TransactionStatus.reversed,
        _ => TransactionStatus.pending,
      };

  /// Fake factory for mock data.
  static List<WalletTransaction> fakeList({int count = 10}) {
    final services = ['mobile_recharge', 'dth', 'bbps', 'dmt', 'wallet_topup', 'aeps'];
    final statuses = TransactionStatus.values;
    return List.generate(
      count,
      (i) => WalletTransaction(
        id: 'TXN${'${i + 1}'.padLeft(6, '0')}',
        serviceType: services[i % services.length],
        operatorName: 'Mock Operator',
        transactionTitle: 'Mock Transaction',
        customerIdentifier: '1234567890',
        amountPaise: (i + 1) * 10000, // ₹100, ₹200, etc.
        commissionEarnedPaise: (i + 1) * 100, // ₹1, ₹2, etc.
        status: statuses[i % statuses.length],
        createdAt: DateTime.now().subtract(Duration(hours: i * 2)),
        completedAt: DateTime.now().subtract(Duration(hours: i * 2)),
        paymentMethod: 'wallet',
        referenceId: 'REF${DateTime.now().millisecondsSinceEpoch}$i',
        description: 'Mock transaction #${i + 1}',
      ),
    );
  }

  @override
  List<Object?> get props => [
        id, isCredit, amountPaise, status, serviceType, createdAt, referenceId
      ];
}
