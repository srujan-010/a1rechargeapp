// lib/core/utils/currency_formatter.dart
// INR currency formatting using the intl package.
// IMPORTANT: All monetary amounts are stored as INTEGER PAISE internally.
// Never use raw double for money arithmetic — use paise (int) and convert only for display.

import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static final NumberFormat _rupeeFormat = NumberFormat.currency(
    locale: 'en_IN',
    customPattern: '\u20B9#,##,##0.00',
    decimalDigits: 2,
  );

  static final NumberFormat _rupeeNoDecimalFormat = NumberFormat.currency(
    locale: 'en_IN',
    customPattern: '\u20B9#,##,##0',
    decimalDigits: 0,
  );

  static final NumberFormat _compactFormat = NumberFormat.compact(
    locale: 'en_IN',
  )..maximumFractionDigits = 1;

  static String _addRupeeToCompact(String compactStr) {
    return '\u20B9$compactStr';
  }

  /// Format paise (int) to display string: ₹1,23,456.78
  static String fromPaise(int paise) {
    final rupees = paise / 100.0;
    return _rupeeFormat.format(rupees);
  }

  /// Format paise (int) without decimal: ₹1,23,456
  static String fromPaiseNoDecimal(int paise) {
    final rupees = paise / 100.0;
    return _rupeeNoDecimalFormat.format(rupees.round());
  }

  /// Format rupee double to display string (use only for display, not calculation)
  static String fromRupees(double rupees) {
    return _rupeeFormat.format(rupees);
  }

  /// Compact format for large numbers: ₹1.2L, ₹5K
  static String fromPaiseCompact(int paise) {
    final rupees = paise / 100.0;
    return _addRupeeToCompact(_compactFormat.format(rupees));
  }

  /// Parse a rupee display string to paise (int).
  /// Strips ₹, commas, spaces before parsing.
  static int? parseToProblems(String value) {
    final cleaned = value
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return null;
    return (parsed * 100).round();
  }

  /// Convert rupees string to paise safely.
  static int? rupeeStringToPaise(String rupeesStr) {
    final cleaned = rupeesStr.replaceAll(',', '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return null;
    return (parsed * 100).round();
  }

  /// Format a number with Indian locale commas: 1,23,456
  static String formatIndian(int number) {
    final format = NumberFormat('#,##,###', 'en_IN');
    return format.format(number);
  }

  /// Paise to rupee double (use only for chart/display, never for arithmetic).
  static double paiseToDraw(int paise) => paise / 100.0;
}
