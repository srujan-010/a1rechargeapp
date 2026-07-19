// lib/core/theme/app_spacing.dart
// Centralized spacing and radius constants.
// Never use raw numeric literals for spacing in widgets — always use these tokens.

abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  static const double pagePadding = 20.0;
  static const double cardPadding = 16.0;
  static const double sectionSpacing = 24.0;
  static const double itemSpacing = 12.0;
}

abstract final class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double pill = 999.0;

  // Named semantic aliases
  static const double card = md;       // 12px for all cards
  static const double button = lg;     // 16px for buttons
  static const double chip = pill;     // Pill-shaped chips
  static const double dialog = xl;     // 20px for bottom sheets + dialogs
  static const double input = sm;      // 8px for text fields
}

abstract final class AppElevation {
  static const double card = 0.0;
  static const double floatingCard = 2.0;
  static const double appBar = 0.0;
  static const double bottomNav = 8.0;
  static const double dialog = 16.0;
}
