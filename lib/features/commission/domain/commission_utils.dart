// lib/features/commission/domain/commission_utils.dart
// Commission display formatting utility.
// Single source of truth — never duplicate this logic inline in widgets or tables.

import 'package:intl/intl.dart';

/// Formats a commission slab value for human display.
///
/// Examples:
///   formatCommission('percentage', 2.0)  → '2.0%'
///   formatCommission('percentage', 1.5)  → '1.5%'
///   formatCommission('flat', 5.0)        → '₹5.00 flat'
///   formatCommission('flat', 10.5)       → '₹10.50 flat'
String formatCommission(String commissionType, double commissionValue) {
  if (commissionType == 'percentage') {
    // Trim trailing zero for whole numbers: 2.0% not 2.00%
    final formatted = commissionValue == commissionValue.truncateToDouble()
        ? commissionValue.toStringAsFixed(1)
        : commissionValue.toString();
    return '$formatted%';
  }

  // Flat rate — format as INR with 2 decimal places
  final flatFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  return '${flatFormat.format(commissionValue)} flat';
}
