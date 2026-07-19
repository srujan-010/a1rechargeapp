// lib/core/utils/validators.dart
// Centralized input validation functions for all forms across A1 Recharge.
// Returns null if valid, or a user-friendly error string if invalid.
// Rules: Indian fintech standards (TRAI mobile format, IFSC, PAN, Aadhaar).

abstract final class AppValidators {
  // ─────────────────────────────────────────────────────────────────
  // Mobile Number (Indian)
  // ─────────────────────────────────────────────────────────────────
  /// Validates a 10-digit Indian mobile number.
  /// Allowed prefixes: 6, 7, 8, 9 (TRAI licensed range).
  static String? mobileNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.length != 10) {
      return 'Enter a valid 10-digit mobile number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return 'Enter a valid Indian mobile number starting with 6–9';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // OTP
  // ─────────────────────────────────────────────────────────────────
  static String? otp(String? value, {int length = 6}) {
    if (value == null || value.trim().isEmpty) {
      return 'OTP is required';
    }
    if (value.trim().length != length) {
      return 'Enter the $length-digit OTP';
    }
    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
      return 'OTP must contain digits only';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // MPIN / Transaction PIN (6-digit)
  // ─────────────────────────────────────────────────────────────────
  static String? mpin(String? value, {int length = 6}) {
    if (value == null || value.isEmpty) {
      return 'PIN is required';
    }
    if (value.length != length) {
      return 'PIN must be exactly $length digits';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'PIN must contain digits only';
    }
    // Reject trivially weak PINs
    if (_isAllSameDigits(value)) {
      return 'PIN cannot be all the same digit (e.g. 111111)';
    }
    if (_isSequential(value)) {
      return 'PIN cannot be sequential digits (e.g. 123456)';
    }
    return null;
  }

  static String? mpinConfirm(String? value, String? original) {
    final pinError = mpin(value);
    if (pinError != null) return pinError;
    if (value != original) return 'PINs do not match';
    return null;
  }

  static bool _isAllSameDigits(String pin) =>
      pin.split('').toSet().length == 1;

  static bool _isSequential(String pin) {
    final digits = pin.split('').map(int.parse).toList();
    bool asc = true;
    bool desc = true;
    for (int i = 1; i < digits.length; i++) {
      if (digits[i] != digits[i - 1] + 1) asc = false;
      if (digits[i] != digits[i - 1] - 1) desc = false;
    }
    return asc || desc;
  }

  // ─────────────────────────────────────────────────────────────────
  // IFSC Code
  // ─────────────────────────────────────────────────────────────────
  /// Format: 4 alpha chars (bank code) + 0 + 6 alphanumeric (branch)
  static String? ifsc(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'IFSC code is required';
    }
    final cleaned = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(cleaned)) {
      return 'Enter a valid IFSC code (e.g. SBIN0001234)';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // PAN Card
  // ─────────────────────────────────────────────────────────────────
  /// Format: 5 letters + 4 digits + 1 letter
  static String? pan(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'PAN number is required';
    }
    final cleaned = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(cleaned)) {
      return 'Enter a valid PAN (e.g. ABCDE1234F)';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // Aadhaar Number
  // ─────────────────────────────────────────────────────────────────
  /// 12-digit numeric. Verhoeff algorithm not enforced (requires backend).
  static String? aadhaar(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Aadhaar number is required';
    }
    final cleaned = value.trim().replaceAll(' ', '');
    if (!RegExp(r'^\d{12}$').hasMatch(cleaned)) {
      return 'Enter a valid 12-digit Aadhaar number';
    }
    if (cleaned.startsWith('0') || cleaned.startsWith('1')) {
      return 'Aadhaar number cannot start with 0 or 1';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // Bank Account Number
  // ─────────────────────────────────────────────────────────────────
  static String? accountNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Account number is required';
    }
    final cleaned = value.trim();
    if (!RegExp(r'^\d{9,18}$').hasMatch(cleaned)) {
      return 'Enter a valid account number (9–18 digits)';
    }
    return null;
  }

  static String? confirmAccountNumber(String? value, String? original) {
    final err = accountNumber(value);
    if (err != null) return err;
    if (value?.trim() != original?.trim()) {
      return 'Account numbers do not match';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // Amount (in Rupees, stored as paise internally)
  // ─────────────────────────────────────────────────────────────────
  static String? amount(
    String? value, {
    int minPaise = 100,       // ₹1 minimum
    int maxPaise = 10000000,  // ₹1 lakh maximum
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final cleaned = value.trim().replaceAll(',', '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return 'Enter a valid amount';
    }
    if (parsed <= 0) {
      return 'Amount must be greater than zero';
    }
    final paise = (parsed * 100).round();
    if (paise < minPaise) {
      return 'Minimum amount is ₹${(minPaise / 100).toStringAsFixed(0)}';
    }
    if (paise > maxPaise) {
      return 'Maximum amount is ₹${(maxPaise / 100).toStringAsFixed(0)}';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // Name / Generic Required Text
  // ─────────────────────────────────────────────────────────────────
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Name must contain letters only';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // DTH Customer ID
  // ─────────────────────────────────────────────────────────────────
  static String? dthCustomerId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Customer ID is required';
    }
    if (!RegExp(r'^\d{10,12}$').hasMatch(value.trim())) {
      return 'Enter a valid Customer ID (10–12 digits)';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // Pincode
  // ─────────────────────────────────────────────────────────────────
  static String? pincode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pincode is required';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Enter a valid 6-digit pincode';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // Email (optional field, used in profile/support)
  // ─────────────────────────────────────────────────────────────────
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }
}
