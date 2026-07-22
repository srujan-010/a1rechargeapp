import 'package:equatable/equatable.dart';

class Biller extends Equatable {
  const Biller({
    required this.id,
    required this.name,
    required this.category,
    required this.iconUrl,
    required this.parameters,
    this.isFetchRequirement = true,
    this.sampleBillUrl,
    this.requiresDistrictCode = false,
    this.requiresMobile = false,
    this.requiresDOB = false,
  });

  final String id;
  final String name;
  final String category; // 'electricity', 'water', 'fastag', etc.
  final String iconUrl;
  final List<BillerParameter> parameters; // Parameters required to fetch the bill
  final bool isFetchRequirement; // true if bill must be fetched before paying
  final String? sampleBillUrl;
  final bool requiresDistrictCode;
  final bool requiresMobile;
  final bool requiresDOB;

  @override
  List<Object?> get props => [id, name, category, parameters, sampleBillUrl, requiresDistrictCode, requiresMobile, requiresDOB];
}

class BillerDistrict extends Equatable {
  const BillerDistrict({
    required this.operatorCode,
    required this.state,
    required this.districtName,
    required this.districtCode,
  });

  final int operatorCode;
  final String state;
  final String districtName;
  final String districtCode;

  @override
  List<Object?> get props => [operatorCode, state, districtName, districtCode];
}

class BillerParameter extends Equatable {
  const BillerParameter({
    required this.name,
    required this.displayName,
    required this.regex,
    this.minLength = 1,
    this.maxLength = 20,
    this.isOptional = false,
    this.helperText,
  });

  final String name; // e.g. "consumer_number"
  final String displayName; // e.g. "Consumer Number"
  final String regex; // Validation regex
  final int minLength;
  final int maxLength;
  final bool isOptional;
  final String? helperText;

  @override
  List<Object?> get props => [name, displayName, regex, isOptional, helperText];
}

class BillDetails extends Equatable {
  const BillDetails({
    required this.billerId,
    required this.billerName,
    required this.customerName,
    required this.billAmountPaise,
    required this.rawBillDate,
    required this.rawDueDate,
    this.parsedBillDate,
    this.parsedDueDate,
    required this.billNumber,
  });

  final String billerId;
  final String billerName;
  final String customerName;
  final int billAmountPaise;
  final String rawBillDate;
  final String rawDueDate;
  final DateTime? parsedBillDate;
  final DateTime? parsedDueDate;
  final String billNumber;

  @override
  List<Object?> get props => [
        billerId,
        billNumber,
        billAmountPaise,
        rawBillDate,
        rawDueDate,
        parsedBillDate,
        parsedDueDate,
      ];
}
