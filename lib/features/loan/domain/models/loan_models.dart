import 'package:equatable/equatable.dart';

class LoanProvider extends Equatable {
  const LoanProvider({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String? logoUrl;

  @override
  List<Object?> get props => [id, name];
}

class LoanDetails extends Equatable {
  const LoanDetails({
    required this.loanAccountNumber,
    required this.customerName,
    required this.providerName,
    required this.emiAmountPaise,
    required this.dueDate,
  });

  final String loanAccountNumber;
  final String customerName;
  final String providerName;
  final int emiAmountPaise;
  final DateTime dueDate;

  @override
  List<Object?> get props => [loanAccountNumber, emiAmountPaise, dueDate];
}
