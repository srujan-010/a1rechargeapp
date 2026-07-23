import 'package:equatable/equatable.dart';

class GasOperator extends Equatable {
  const GasOperator({
    required this.id,
    required this.name,
    this.shortName,
    required this.planApiCode,
    required this.a1TopupCode,
    this.isActive = true,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String? shortName;
  final int planApiCode;
  final String a1TopupCode;
  final bool isActive;
  final String? iconUrl;

  @override
  List<Object?> get props => [id, name, shortName, planApiCode, a1TopupCode, isActive, iconUrl];

  factory GasOperator.fromJson(Map<String, dynamic> json) {
    return GasOperator(
      id: json['_id'] as String,
      name: json['name'] as String,
      shortName: json['shortName'] as String?,
      planApiCode: (json['planApi'] != null) ? (json['planApi']['operatorCode'] as int? ?? 0) : 0,
      a1TopupCode: (json['a1Topup'] != null) ? (json['a1Topup']['operatorCode'] as String? ?? '') : '',
      isActive: json['isActive'] as bool? ?? true,
      iconUrl: json['logo'] as String?,
    );
  }
}

class GasBill extends Equatable {
  const GasBill({
    required this.billerId,
    required this.billerName,
    required this.customerName,
    required this.billAmount,
    required this.billDate,
    required this.dueDate,
    required this.billNumber,
  });

  final String billerId;
  final String billerName;
  final String customerName;
  final String billAmount;
  final String billDate;
  final String dueDate;
  final String billNumber;

  @override
  List<Object?> get props => [
        billerId,
        billerName,
        customerName,
        billAmount,
        billDate,
        dueDate,
        billNumber,
      ];

  factory GasBill.fromJson(Map<String, dynamic> json) {
    return GasBill(
      billerId: json['billerId'] as String,
      billerName: json['billerName'] as String,
      customerName: json['customerName'] as String,
      billAmount: json['billAmount'] as String,
      billDate: json['billDate'] as String,
      dueDate: json['dueDate'] as String,
      billNumber: json['billNumber'] as String,
    );
  }
}
