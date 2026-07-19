// lib/core/theme/app_colors.dart
// Central color token definitions for A1 Recharge.
// All colors must be referenced from here — never inline raw Color values in widgets.

import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueDark = Color(0xFF1D4ED8);
  static const Color primaryBlueLight = Color(0xFFEFF6FF);

  // Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color pending = Color(0xFFF59E0B);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Dividers
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderFocus = Color(0xFF2563EB);

  // Gradient
  static const List<Color> primaryGradient = [
    Color(0xFF1E40AF),
    Color(0xFF2563EB),
    Color(0xFF3B82F6),
  ];

  // Service icon backgrounds
  static const Color serviceMobile = Color(0xFFEFF6FF);
  static const Color serviceDTH = Color(0xFFF5F3FF);
  static const Color serviceElectricity = Color(0xFFFFFBEB);
  static const Color serviceBBPS = Color(0xFFECFDF5);
  static const Color serviceAEPS = Color(0xFFFFF7ED);
  static const Color serviceDMT = Color(0xFFFDF2F8);

  // Transaction status colors
  static Color statusSuccess = success;
  static Color statusPending = warning;
  static Color statusFailed = error;

  // Shadow
  static const Color shadowSoft = Color(0x0A000000);
  static const Color shadowMedium = Color(0x14000000);
}
