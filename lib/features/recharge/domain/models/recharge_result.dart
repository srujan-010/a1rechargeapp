// lib/features/recharge/domain/models/recharge_result.dart
import 'package:equatable/equatable.dart';

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

  bool get isSuccess => status == RechargeStatus.success;
  bool get isFailed => status == RechargeStatus.failed;

  factory RechargeReceipt.fromJson(Map<String, dynamic> json) =>
      RechargeReceipt(
        transactionId: json['transactionId'] as String? ?? '',
        referenceId: json['referenceId'] as String? ?? '',
        mobileNumber: json['mobileNumber'] as String? ?? '',
        operatorName: json['operatorName'] as String? ?? '',
        amountPaise: (json['amountPaise'] as num?)?.toInt() ?? (json['amount'] as num?)?.toInt() ?? 0,
        status: _parseStatus(json['status'] as String?),
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        planDescription: json['planDescription'] as String?,
        validity: json['validity'] as String?,
        operatorRef: json['operatorRef'] as String?,
        commission: (json['commissionEarnedPaise'] as num?)?.toInt() ?? (json['commission'] as num?)?.toInt(),
        walletDebitedPaise: (json['walletDebitedPaise'] as num?)?.toInt(),
        failureReason: json['failureReason'] as String?,
        paymentMode: json['paymentMode'] as String? ?? 'Wallet',
        circle: json['circle'] as String?,
        walletBalancePaise: (json['walletBalanceAfterPaise'] as num?)?.toInt() ?? (json['walletBalancePaise'] as num?)?.toInt(),
      );

  static RechargeStatus _parseStatus(String? raw) => switch (raw) {
        'success' => RechargeStatus.success,
        'failed' => RechargeStatus.failed,
        'processing' => RechargeStatus.processing,
        _ => RechargeStatus.pending,
      };

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
