// lib/features/recharge/domain/models/operator.dart
import 'package:equatable/equatable.dart';

enum OperatorType { prepaid, postpaid, dth }

class Operator extends Equatable {
  const Operator({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.type,
    this.circle,
    this.shortCode,
    this.planApiCode,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String logoUrl;
  final OperatorType type;
  final String? circle;
  final String? shortCode;
  final String? planApiCode;
  final bool isActive;

  String? get code => shortCode;

  factory Operator.fromJson(Map<String, dynamic> json) => Operator(
        id: json['id'] as String? ?? json['_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        logoUrl: json['logoUrl'] as String? ?? '',
        type: _parseType((json['type'] ?? json['serviceType']) as String?),
        circle: json['circle'] as String?,
        shortCode: json['shortCode'] as String? ?? json['code'] as String?,
        planApiCode: json['plansInfoCode'] as String? ?? json['planApiCode'] as String?,
        isActive: json['isActive'] as bool? ?? json['status'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
        'type': type.name,
        'circle': circle,
        'shortCode': shortCode,
        'planApiCode': planApiCode,
        'isActive': isActive,
      };

  static OperatorType _parseType(String? raw) => switch (raw?.trim().toLowerCase()) {
        'postpaid' => OperatorType.postpaid,
        'dth' => OperatorType.dth,
        _ => OperatorType.prepaid,
      };

  factory Operator.fake({String? id, String? name, OperatorType? type}) =>
      Operator(
        id: id ?? 'OP001',
        name: name ?? 'Jio',
        logoUrl: 'https://via.placeholder.com/80x80.png?text=JIO',
        type: type ?? OperatorType.prepaid,
        circle: 'Andhra Pradesh',
        shortCode: 'JIO',
      );

  static List<Operator> fakeList() => [
        Operator.fake(id: 'OP001', name: 'Jio', type: OperatorType.prepaid),
        Operator.fake(id: 'OP002', name: 'Airtel', type: OperatorType.prepaid),
        Operator.fake(id: 'OP003', name: 'Vi (Vodafone Idea)', type: OperatorType.prepaid),
        Operator.fake(id: 'OP004', name: 'BSNL', type: OperatorType.prepaid),
        Operator.fake(id: 'OP005', name: 'Airtel Postpaid', type: OperatorType.postpaid),
        Operator.fake(id: 'OP006', name: 'Tata Play', type: OperatorType.dth),
        Operator.fake(id: 'OP007', name: 'Dish TV', type: OperatorType.dth),
        Operator.fake(id: 'OP008', name: 'Airtel DTH', type: OperatorType.dth),
      ];

  @override
  List<Object?> get props => [id, name, type, circle];
}
