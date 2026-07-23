import 'package:equatable/equatable.dart';

class FastagOperator extends Equatable {
  const FastagOperator({
    required this.id,
    required this.name,
    required this.operatorCode,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String operatorCode;
  final String? iconUrl;

  @override
  List<Object?> get props => [id, name, operatorCode, iconUrl];

  factory FastagOperator.fromJson(Map<String, dynamic> json) {
    return FastagOperator(
      id: json['_id'] as String,
      name: json['name'] as String,
      operatorCode: json['operatorCode'].toString(),
      iconUrl: json['logo'] as String?,
    );
  }
}

class FastagDetails extends Equatable {
  const FastagDetails({
    required this.billerId,
    required this.billerName,
    required this.customerName,
    required this.vehicleNumber,
    required this.status,
  });

  final String billerId;
  final String billerName;
  final String customerName;
  final String vehicleNumber;
  final String status;

  @override
  List<Object?> get props => [
        billerId,
        billerName,
        customerName,
        vehicleNumber,
        status,
      ];

  factory FastagDetails.fromJson(Map<String, dynamic> json) {
    return FastagDetails(
      billerId: json['billerId'] as String,
      billerName: json['billerName'] as String,
      customerName: json['customerName'] as String,
      vehicleNumber: json['vehicleNumber'] as String,
      status: json['status'] as String,
    );
  }
}
