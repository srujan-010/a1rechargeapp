// lib/features/commission/domain/models/commission_slab.dart
// Commission rate slab set by the A1 Topup platform per operator and service type.
// commissionType == 'percentage' → commissionValue is a % of transaction amount.
// commissionType == 'flat'       → commissionValue is a fixed INR amount per transaction.

import 'package:equatable/equatable.dart';

class CommissionSlab extends Equatable {
  const CommissionSlab({
    required this.id,
    required this.serviceType,
    required this.operatorName,
    required this.commissionType,
    required this.commissionValue,
    required this.effectiveFrom,
    this.operatorLogoUrl,
    this.effectiveTo,
  });

  final String id;

  /// 'mobile' | 'dth' | 'bbps' | 'aeps' | 'dmt' | 'insurance' | 'loan'
  final String serviceType;

  final String operatorName;
  final String? operatorLogoUrl;

  /// 'percentage' | 'flat'
  final String commissionType;

  /// 2.0 means 2% for percentage slabs, or ₹2.00 flat for flat slabs.
  final double commissionValue;

  final DateTime effectiveFrom;

  /// null = currently active slab
  final DateTime? effectiveTo;

  bool get isActive => effectiveTo == null || DateTime.now().isBefore(effectiveTo!);

  factory CommissionSlab.fromJson(Map<String, dynamic> json) => CommissionSlab(
        id: json['id'] as String? ?? '',
        serviceType: json['serviceType'] as String? ?? 'mobile',
        operatorName: json['operatorName'] as String? ?? '',
        operatorLogoUrl: json['operatorLogoUrl'] as String?,
        commissionType: json['commissionType'] as String? ?? 'percentage',
        commissionValue: (json['commissionValue'] as num?)?.toDouble() ?? 0.0,
        effectiveFrom: json['effectiveFrom'] != null
            ? DateTime.parse(json['effectiveFrom'] as String)
            : DateTime(2024),
        effectiveTo: json['effectiveTo'] != null
            ? DateTime.parse(json['effectiveTo'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceType': serviceType,
        'operatorName': operatorName,
        'operatorLogoUrl': operatorLogoUrl,
        'commissionType': commissionType,
        'commissionValue': commissionValue,
        'effectiveFrom': effectiveFrom.toIso8601String(),
        'effectiveTo': effectiveTo?.toIso8601String(),
      };

  /// Fake factory for tests and mock repositories.
  factory CommissionSlab.fake({
    String id = 'SLAB001',
    String serviceType = 'mobile',
    String operatorName = 'Airtel',
    String commissionType = 'percentage',
    double commissionValue = 2.0,
  }) =>
      CommissionSlab(
        id: id,
        serviceType: serviceType,
        operatorName: operatorName,
        commissionType: commissionType,
        commissionValue: commissionValue,
        effectiveFrom: DateTime(2024),
      );

  @override
  List<Object?> get props => [
        id,
        serviceType,
        operatorName,
        commissionType,
        commissionValue,
        effectiveFrom,
        effectiveTo,
      ];
}
