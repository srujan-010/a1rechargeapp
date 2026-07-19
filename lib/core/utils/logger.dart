// lib/core/utils/logger.dart
// Debug-only structured logger.
// In release builds, all log calls are no-ops (compile-time constant check).
// Never use print() directly in the codebase — always use AppLogger.

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

abstract final class AppLogger {
  static const bool _isDebug = kDebugMode;

  /// Log a debug message (verbose — only during development)
  static void debug(String message, {String? tag, Object? data}) {
    if (!_isDebug) return;
    _log(LogLevel.debug, message, tag: tag, data: data);
  }

  /// Log an informational message (important app events)
  static void info(String message, {String? tag, Object? data}) {
    if (!_isDebug) return;
    _log(LogLevel.info, message, tag: tag, data: data);
  }

  /// Log a warning (non-fatal unexpected state)
  static void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (!_isDebug) return;
    _log(LogLevel.warning, message, tag: tag, data: error);
    if (stackTrace != null && _isDebug) {
      debugPrint('  StackTrace: $stackTrace');
    }
  }

  /// Log an error (fatal or user-impacting error)
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (!_isDebug) return;
    _log(LogLevel.error, message, tag: tag, data: error);
    if (stackTrace != null) {
      debugPrint('  StackTrace: $stackTrace');
    }
  }

  static void _log(LogLevel level, String message, {String? tag, Object? data}) {
    final emoji = switch (level) {
      LogLevel.debug => '🔍',
      LogLevel.info => 'ℹ️ ',
      LogLevel.warning => '⚠️ ',
      LogLevel.error => '❌',
    };
    final prefix = tag != null ? '[$tag]' : '';
    debugPrint('$emoji A1Recharge $prefix $message${data != null ? '\n  Data: $data' : ''}');
  }
}
