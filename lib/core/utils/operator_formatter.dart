// lib/core/utils/operator_formatter.dart
/// Centralized Operator Display Formatter for A1 Recharge Personal Account
///
/// Normalizes internal/provider operator codes and raw strings into clean,
/// customer-facing display names without altering backend/provider codes.
class OperatorFormatter {
  /// Returns a clean, user-friendly display name for an operator string or code.
  /// Example:
  /// - "AT" -> "Airtel"
  /// - "AIRTEL" -> "Airtel"
  /// - "RJIO" -> "Jio"
  /// - "JIO" -> "Jio"
  /// - "BSNL TOPUP" -> "BSNL"
  /// - "VI" -> "Vi"
  static String getDisplayOperatorName(String? rawOperator) {
    if (rawOperator == null || rawOperator.trim().isEmpty) {
      return 'Mobile Operator';
    }

    final cleaned = rawOperator.trim().toUpperCase();

    // ── AIRTEL ──
    if (cleaned == 'AT' ||
        cleaned == 'AIRTEL' ||
        cleaned == 'AIRTEL MOBILE' ||
        cleaned == '2' ||
        cleaned == '13' ||
        cleaned == 'DA') {
      return 'Airtel';
    }

    // ── RELIANCE JIO ──
    if (cleaned == 'JO' ||
        cleaned == 'JIO' ||
        cleaned == 'RJIO' ||
        cleaned == 'RELIANCE JIO' ||
        cleaned == 'RELIANCE_JIO' ||
        cleaned == 'RELIANCEJIO' ||
        cleaned == '11') {
      return 'Jio';
    }

    // ── VODAFONE IDEA / VI ──
    if (cleaned == 'VI' ||
        cleaned == 'VF' ||
        cleaned == 'VODAFONE' ||
        cleaned == 'IDEA' ||
        cleaned == 'VODAFONE IDEA' ||
        cleaned == 'VODAFONE_IDEA' ||
        cleaned == 'VODAFONE/IDEA' ||
        cleaned == '23' ||
        cleaned == '6') {
      return 'Vi';
    }

    // ── BSNL ──
    if (cleaned == 'BT' ||
        cleaned == '4' ||
        cleaned == 'BSNL TOPUP' ||
        cleaned == 'BSNL_TOPUP') {
      return 'BSNL TOPUP';
    }
    if (cleaned == 'BR' ||
        cleaned == '5' ||
        cleaned == 'BSNL SPECIAL' ||
        cleaned == 'BSNL STV' ||
        cleaned == 'BSNL_STV') {
      return 'BSNL SPECIAL';
    }
    if (cleaned == 'BSNL' || cleaned.startsWith('BSNL')) {
      return 'BSNL';
    }

    // ── DTH OPERATORS ──
    if (cleaned == 'DT' || cleaned.contains('TATA PLAY') || cleaned.contains('TATA SKY') || cleaned == '12') {
      return 'Tata Play';
    }
    if (cleaned == 'DD' || cleaned.contains('DISH TV') || cleaned == '14') {
      return 'Dish TV';
    }
    if (cleaned == 'DS' || cleaned.contains('SUN DIRECT') || cleaned == '15') {
      return 'Sun Direct';
    }
    if (cleaned == 'DV' || cleaned.contains('VIDEOCON') || cleaned.contains('D2H') || cleaned == '16') {
      return 'd2h';
    }

    // Short abbreviations fallback
    if (cleaned.length <= 3) {
      return cleaned;
    }

    // Format title case for multi-word strings
    return rawOperator.trim().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
