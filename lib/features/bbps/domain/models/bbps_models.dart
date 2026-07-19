import 'package:equatable/equatable.dart';

class Biller extends Equatable {
  const Biller({
    required this.id,
    required this.name,
    required this.category,
    required this.iconUrl,
    required this.parameters,
    this.isFetchRequirement = true,
  });

  final String id;
  final String name;
  final String category; // 'electricity', 'water', 'fastag', etc.
  final String iconUrl;
  final List<BillerParameter> parameters; // Parameters required to fetch the bill
  final bool isFetchRequirement; // true if bill must be fetched before paying

  @override
  List<Object?> get props => [id, name, category, parameters];
}

class BillerParameter extends Equatable {
  const BillerParameter({
    required this.name,
    required this.displayName,
    required this.regex,
    this.minLength = 1,
    this.maxLength = 20,
  });

  final String name; // e.g. "consumer_number"
  final String displayName; // e.g. "Consumer Number"
  final String regex; // Validation regex
  final int minLength;
  final int maxLength;

  @override
  List<Object?> get props => [name, displayName, regex];
}

class BillDetails extends Equatable {
  const BillDetails({
    required this.billerId,
    required this.billerName,
    required this.customerName,
    required this.billAmountPaise,
    required this.billDate,
    required this.dueDate,
    required this.billNumber,
  });

  final String billerId;
  final String billerName;
  final String customerName;
  final int billAmountPaise;
  final DateTime billDate;
  final DateTime dueDate;
  final String billNumber;

  @override
  List<Object?> get props => [billerId, billNumber, billAmountPaise];
}
