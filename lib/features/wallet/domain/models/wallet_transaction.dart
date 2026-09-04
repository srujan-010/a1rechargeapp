// lib/features/wallet/domain/models/wallet_transaction.dart
import 'package:equatable/equatable.dart';

import '../../../../core/utils/operator_formatter.dart';

enum TransactionType { credit, debit }
enum TransactionStatus { success, pending, processing, failed, reversed }
enum TransactionCategory { recharge, walletCredit, walletDebit, commission, bills, other }

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
    this.reason,
    this.adminName,
    this.closingBalancePaise,
    this.type,
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
  final String? reason;
  final String? adminName;
  final int? closingBalancePaise;
  final String? type;

  String get displayOperatorName => OperatorFormatter.getDisplayOperatorName(operatorName);

  bool get isCredit {
    final tLower = (type ?? '').toLowerCase();
    final sLower = serviceType.toLowerCase();
    if (tLower == 'debit' || sLower == 'admin_debit' || sLower.contains('debit')) return false;
    if (tLower == 'credit' || sLower == 'admin_credit' || sLower.contains('credit') || sLower.contains('topup')) return true;
    return false;
  }
  bool get isDebit => !isCredit;

  TransactionCategory get category {
    final sLower = serviceType.toLowerCase();
    final tLower = (type ?? '').toLowerCase();

    if (sLower == 'mobile_recharge' || sLower == 'mobile' || sLower == 'dth') {
      return TransactionCategory.recharge;
    }
    if (sLower == 'commission') {
      return TransactionCategory.commission;
    }
    if (sLower == 'bbps' || sLower == 'electricity' || sLower == 'water' || sLower == 'gas' || sLower == 'fastag' || sLower == 'broadband') {
      return TransactionCategory.bills;
    }
    if (isCredit) {
      return TransactionCategory.walletCredit;
    }
    if (tLower == 'debit' || sLower.contains('debit')) {
      return TransactionCategory.walletDebit;
    }
    return TransactionCategory.other;
  }

  static String? _asString(dynamic val) {
    if (val == null) return null;
    return val.toString();
  }

  static int? _asInt(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    if (val is String) {
      final n = num.tryParse(val);
      if (n != null) return n.toInt();
    }
    return null;
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic val) {
      if (val == null) return DateTime.now();
      final str = val.toString();
      final dt = DateTime.tryParse(str);
      if (dt == null) return DateTime.now();
      return dt.toLocal();
    }

    final rawOp = _asString(json['operatorName'] ?? json['operator'] ?? json['operatorCode']) ?? '';
    final rawType = _asString(json['type']);
    final rawService = _asString(json['serviceType'] ?? json['service']) ?? 'unknown';
    final isAdminService = rawService == 'admin_credit' || rawService == 'admin_debit';

    return WalletTransaction(
      id: _asString(json['id'] ?? json['_id']) ?? '',
      serviceType: rawService,
      operatorName: isAdminService ? 'Admin' : OperatorFormatter.getDisplayOperatorName(rawOp),
      transactionTitle: _asString(json['transactionTitle']) ?? (rawService == 'admin_credit' ? 'ADMIN CREDIT' : (rawService == 'admin_debit' ? 'ADMIN DEBIT' : 'Transaction')),
      customerIdentifier: _asString(json['customerIdentifier'] ?? json['mobileNumber']) ?? '',
      amountPaise: _asInt(json['amount']) ?? _asInt(json['amountPaise']) ?? 0,
      commissionEarnedPaise: _asInt(json['commission']) ?? _asInt(json['commissionEarnedPaise']) ?? _asInt(json['commissionAmountPaise']) ?? 0,
      status: _parseStatus(_asString(json['status'])),
      createdAt: parseTimestamp(json['createdAt'] ?? json['timestamp']),
      completedAt: parseTimestamp(json['completedAt'] ?? json['timestamp']),
      paymentMethod: isAdminService ? 'ADMIN' : (_asString(json['paymentMethod']) ?? 'wallet'),
      referenceId: _asString(json['referenceNumber'] ?? json['referenceId'] ?? json['orderId'] ?? json['clientOrderId']) ?? '',
      apiReference: _asString(json['apiReference'] ?? json['providerTransactionId']),
      description: _asString(json['description']),
      reason: _asString(json['reason'] ?? json['description']),
      adminName: _asString(json['performedBy'] ?? json['adminName']),
      closingBalancePaise: _asInt(json['closingBalancePaise'] ?? json['closingBalance']),
      type: rawType,
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

  static TransactionStatus _parseStatus(String? raw) => switch (raw?.toLowerCase()) {
        'success' => TransactionStatus.success,
        'processing' || 'recharge_processing' || 'submitted' || 'initiated' => TransactionStatus.processing,
        'pending' => TransactionStatus.pending,
        'failed' => TransactionStatus.failed,
        'reversed' || 'refunded' => TransactionStatus.reversed,
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
