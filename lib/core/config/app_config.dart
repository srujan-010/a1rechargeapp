// lib/core/config/app_config.dart
// Environment configuration loaded from --dart-define values at build time.
// Usage:
//   flutter run --dart-define=ENV=dev --dart-define=USE_MOCK_API=true
//   flutter run --dart-define=ENV=prod --dart-define=BASE_URL=https://api.a1recharge.com
//
// SECURITY: Never commit real API keys or base URLs with embedded credentials.
// Use --dart-define or CI secrets injection — never hardcode in source.

import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/logger.dart';

enum Environment { dev, staging, prod }

abstract final class AppConfig {
  // ─── Dart-define injection (compile-time constants) ───────────────
  static const String _env =
      String.fromEnvironment('ENV', defaultValue: 'dev');

  static const String _baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '', 
  );

  static const String _lanIp = String.fromEnvironment(
    'LAN_IP',
    defaultValue: '192.168.0.111', 
  );

  static late String _initializedBaseUrl;

  static const bool _useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false, // Switch to real API
  );

  // ─── Public accessors ─────────────────────────────────────────────
  static Environment get environment => switch (_env) {
        'prod' => Environment.prod,
        'staging' => Environment.staging,
        _ => Environment.dev,
      };

  static bool get isProduction => environment == Environment.prod;
  static bool get isDevelopment => environment == Environment.dev;
  static bool get useMockApi => _useMockApi;

  static Future<void> init() async {
    if (_baseUrl.isNotEmpty) {
      _initializedBaseUrl = _baseUrl;
      AppLogger.info('API Base URL configured as (from BASE_URL): $_initializedBaseUrl', tag: 'Config');
      return;
    }

    if (isDevelopment) {
      _initializedBaseUrl = 'https://a1rechargeapp.onrender.com/api';
    } else {
      _initializedBaseUrl = 'https://a1rechargeapp.onrender.com/api';
    }
    
    AppLogger.info('API Base URL configured as: $_initializedBaseUrl', tag: 'Config');
  }

  static String get baseUrl => _initializedBaseUrl;

  // ─── App constants ────────────────────────────────────────────────
  static const String appName = 'A1 Recharge';
  static const String packageId = 'com.a1recharge.app';
  static const String supportPhone = '+91 9975600499';
  static const String supportWhatsApp = '919975600499';
  static const String supportEmail = 'vasavitechsolutions06@gmail.com';

  // ─── Timeout durations ────────────────────────────────────────────
  // Increased to 90 seconds to generously accommodate Render's free tier cold starts
  static const Duration connectTimeout = Duration(seconds: 90);
  static const Duration receiveTimeout = Duration(seconds: 90);
  static const Duration sendTimeout = Duration(seconds: 90);

  // ─── Session / Security ───────────────────────────────────────────
  /// Inactivity auto-logout duration
  static const Duration inactivityTimeout = Duration(minutes: 15);
  static const int maxPinAttempts = 5;
  static const int otpLength = 6;
  static const int pinLength = 6;
  static const int otpResendSeconds = 60;

  // ─── Pagination ───────────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int transactionPageSize = 20;
  static const int planPageSize = 30;

  // ─── Mock API latency (simulates slow 3G) ─────────────────────────
  static const Duration mockLatencyMin = Duration(milliseconds: 800);
  static const Duration mockLatencyMax = Duration(milliseconds: 2000);

  // SSL Pinning — Extension point: enable before production release
  // See: lib/core/services/api_client.dart → _configureSslPinning()
  // TODO: Replace with real certificate SHA-256 fingerprints before go-live
  static const bool enableSslPinning = false;
  static const List<String> sslPinFingerprints = [];
}
