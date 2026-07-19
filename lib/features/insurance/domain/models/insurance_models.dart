import 'package:equatable/equatable.dart';

class InsuranceProvider extends Equatable {
  const InsuranceProvider({
    required this.id,
    required this.name,
    this.logoUrl,
    this.requiresDob = false,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final bool requiresDob; // Some providers require Date of Birth along with Policy Number

  @override
  List<Object?> get props => [id, name, requiresDob];
}

class PolicyDetails extends Equatable {
  const PolicyDetails({
    required this.policyNumber,
    required this.customerName,
    required this.providerName,
    required this.premiumAmountPaise,
    required this.dueDate,
  });

  final String policyNumber;
  final String customerName;
  final String providerName;
  final int premiumAmountPaise;
  final DateTime dueDate;

  @override
  List<Object?> get props => [policyNumber, premiumAmountPaise, dueDate];
}
