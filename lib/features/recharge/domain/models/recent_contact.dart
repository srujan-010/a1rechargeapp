import 'package:equatable/equatable.dart';

class RecentContact extends Equatable {
  const RecentContact({
    required this.phone,
    required this.operatorId,
    required this.circle,
    this.contactName,
    required this.lastRechargeDate,
    required this.lastRechargeAmountPaise,
    this.rechargeCount = 1,
  });

  final String phone;
  final String operatorId;
  final String circle;
  final String? contactName;
  final DateTime lastRechargeDate;
  final int lastRechargeAmountPaise;
  final int rechargeCount;

  factory RecentContact.fromJson(Map<String, dynamic> json) => RecentContact(
        phone: json['phone'] as String? ?? '',
        operatorId: json['operatorId'] as String? ?? '',
        circle: json['circle'] as String? ?? '',
        contactName: json['contactName'] as String?,
        lastRechargeDate: json['lastRechargeDate'] != null
            ? DateTime.parse(json['lastRechargeDate'] as String)
            : DateTime.now(),
        lastRechargeAmountPaise: (json['lastRechargeAmountPaise'] as num?)?.toInt() ?? 0,
        rechargeCount: (json['rechargeCount'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'operatorId': operatorId,
        'circle': circle,
        'contactName': contactName,
        'lastRechargeDate': lastRechargeDate.toIso8601String(),
        'lastRechargeAmountPaise': lastRechargeAmountPaise,
        'rechargeCount': rechargeCount,
      };

  RecentContact copyWith({
    String? phone,
    String? operatorId,
    String? circle,
    String? contactName,
    DateTime? lastRechargeDate,
    int? lastRechargeAmountPaise,
    int? rechargeCount,
  }) {
    return RecentContact(
      phone: phone ?? this.phone,
      operatorId: operatorId ?? this.operatorId,
      circle: circle ?? this.circle,
      contactName: contactName ?? this.contactName,
      lastRechargeDate: lastRechargeDate ?? this.lastRechargeDate,
      lastRechargeAmountPaise: lastRechargeAmountPaise ?? this.lastRechargeAmountPaise,
      rechargeCount: rechargeCount ?? this.rechargeCount,
    );
  }

  @override
  List<Object?> get props => [
        phone,
        operatorId,
        circle,
        contactName,
        lastRechargeDate,
        lastRechargeAmountPaise,
        rechargeCount,
      ];
}
