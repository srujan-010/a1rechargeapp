// lib/features/recharge/domain/models/recharge_result.dart
import 'package:equatable/equatable.dart';

import '../../../../core/utils/operator_formatter.dart';

enum RechargeStatus { pending, success, failed, processing }

class RechargeRequest extends Equatable {
  const RechargeRequest({
    required this.mobileNumber,
    required this.operatorId,
    required this.operatorName,
    required this.serviceType,
    required this.amountPaise,
    this.planId,
    this.transactionPin,
  });

  final String mobileNumber;
  final String operatorId;
  final String operatorName;
  final String serviceType;
  final int amountPaise;
  final String? planId;
  final String? transactionPin; // Cleared after submission, never logged

  Map<String, dynamic> toJson() => {
        'mobileNumber': mobileNumber,
        'operatorId': operatorId,
        'operatorName': operatorName,
        'serviceType': serviceType,
        'amount': amountPaise,
        if (planId != null) 'planId': planId,
        // transactionPin is sent but never stored locally
      };

  @override
  List<Object?> get props => [mobileNumber, operatorId, operatorName, serviceType, amountPaise, planId];
}

class RechargeReceipt extends Equatable {
  const RechargeReceipt({
    required this.transactionId,
    required this.referenceId,
    required this.mobileNumber,
    required this.operatorName,
    required this.amountPaise,
    required this.status,
    required this.timestamp,
    this.planDescription,
    this.validity,
    this.operatorRef,
    this.commission,
    this.failureReason,
    this.paymentMode = 'Wallet',
    this.circle,
    this.walletDebitedPaise,
    this.walletBalancePaise,
  });

  final String transactionId;
  final String referenceId;
  final String mobileNumber;
  final String operatorName;
  final int amountPaise;
  final RechargeStatus status;
  final DateTime timestamp;
  final String? planDescription;
  final String? validity;
  final String? operatorRef;
  final int? commission; // Commission earned in paise
  final int? walletDebitedPaise;
  final String? failureReason;
  final String paymentMode;
  final String? circle;
  final int? walletBalancePaise;

  String get displayOperatorName => OperatorFormatter.getDisplayOperatorName(operatorName);

  bool get isSuccess => status == RechargeStatus.success;
  bool get isFailed => status == RechargeStatus.failed;
  bool get isPending => status == RechargeStatus.pending || status == RechargeStatus.processing;


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

  factory RechargeReceipt.fromJson(Map<String, dynamic> json) {
    final rawOp = _asString(json['operatorName'] ?? json['operator'] ?? json['operatorCode']) ?? '';
    final rawTxnId = _asString(json['transactionId'] ?? json['orderId'] ?? json['referenceId']) ?? '';
    final rawRefId = _asString(json['referenceId'] ?? json['orderId'] ?? json['transactionId']) ?? '';
    final rawOpRef = _asString(json['operatorRef'] ?? json['operatorReference'] ?? json['providerTransactionId']);
    final rawStatus = _asString(json['status'] ?? json['Status'] ?? json['providerStatus']);
    final rawFailureReason = _asString(json['failureReason'] ?? json['message'] ?? json['error']);

    DateTime parsedTimestamp = DateTime.now();
    if (json['timestamp'] != null) {
      final tsStr = json['timestamp'].toString();
      parsedTimestamp = DateTime.tryParse(tsStr) ?? DateTime.now();
    }

    return RechargeReceipt(
      transactionId: rawTxnId,
      referenceId: rawRefId,
      mobileNumber: _asString(json['mobileNumber'] ?? json['mobile'] ?? json['phoneNumber']) ?? '',
      operatorName: OperatorFormatter.getDisplayOperatorName(rawOp),
      amountPaise: _asInt(json['amountPaise']) ?? _asInt(json['amount']) ?? 0,
      status: _parseStatus(rawStatus),
      timestamp: parsedTimestamp,
      planDescription: _asString(json['planDescription']),
      validity: _asString(json['validity']),
      operatorRef: rawOpRef,
      commission: _asInt(json['commissionEarnedPaise'] ?? json['commissionAmountPaise'] ?? json['commission']),
      walletDebitedPaise: _asInt(json['walletDebitedPaise'] ?? json['payableAmountPaise']),
      failureReason: rawFailureReason,
      paymentMode: _asString(json['paymentMode']) ?? 'Wallet',
      circle: _asString(json['circle']),
      walletBalancePaise: _asInt(json['walletBalanceAfterPaise'] ?? json['walletBalancePaise']),
    );
  }

  static RechargeStatus _parseStatus(String? raw) {
    if (raw == null) return RechargeStatus.pending;
    final normalized = raw.toLowerCase().trim();
    return switch (normalized) {
      'success' || 'completed' || 'payment_success' || 'recharge_success' || 'successful' || 'success_paid' => RechargeStatus.success,
      'failed' || 'failure' || 'rejected' || 'error' => RechargeStatus.failed,
      'processing' || 'pending' || 'in_progress' => RechargeStatus.processing,
      _ => RechargeStatus.pending,
    };
  }

  factory RechargeReceipt.fake({bool success = true}) => RechargeReceipt(
        transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}',
        referenceId: 'REF1234567890',
        mobileNumber: '9876543210',
        operatorName: 'Jio',
        amountPaise: 23900,
        status: success ? RechargeStatus.success : RechargeStatus.failed,
        timestamp: DateTime.now(),
        planDescription: '2GB/day, Unlimited Calls',
        validity: '28 Days',
        operatorRef: 'JIO9876543210',
        commission: 500, // ₹5
        walletDebitedPaise: 23400,
        failureReason: success ? null : 'Operator temporarily unavailable',
        paymentMode: 'Wallet',
        circle: 'Delhi NCR',
        walletBalancePaise: 154500, // ₹1545.00
      );

  RechargeReceipt copyWith({
    RechargeStatus? status,
    String? operatorRef,
    String? failureReason,
    int? commission,
    int? walletDebitedPaise,
    String? paymentMode,
    String? circle,
    int? walletBalancePaise,
  }) {
    return RechargeReceipt(
      transactionId: transactionId,
      referenceId: referenceId,
      mobileNumber: mobileNumber,
      operatorName: operatorName,
      amountPaise: amountPaise,
      status: status ?? this.status,
      timestamp: timestamp,
      planDescription: planDescription,
      validity: validity,
      operatorRef: operatorRef ?? this.operatorRef,
      commission: commission ?? this.commission,
      walletDebitedPaise: walletDebitedPaise ?? this.walletDebitedPaise,
      failureReason: failureReason ?? this.failureReason,
      paymentMode: paymentMode ?? this.paymentMode,
      circle: circle ?? this.circle,
      walletBalancePaise: walletBalancePaise ?? this.walletBalancePaise,
    );
  }

  @override
  List<Object?> get props =>
      [transactionId, mobileNumber, amountPaise, status, timestamp, paymentMode];
}
