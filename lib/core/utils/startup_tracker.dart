import 'package:flutter/foundation.dart';
import 'logger.dart';

/// Tracks application startup milestones and logs total timing metrics.
class StartupTracker {
  StartupTracker._internal();
  static final StartupTracker instance = StartupTracker._internal();

  DateTime? _appStartedTime;
  DateTime? _splashStartedTime;
  DateTime? _localInitCompletedTime;
  DateTime? _navDecisionCompletedTime;
  DateTime? _dashboardDisplayedTime;
  DateTime? _backgroundTasksStartedTime;
  DateTime? _backgroundTasksCompletedTime;

  bool _hasPrintedSummary = false;

  void markAppStarted() {
    _appStartedTime ??= DateTime.now();
  }

  void markSplashStarted() {
    _splashStartedTime ??= DateTime.now();
  }

  void markLocalInitCompleted() {
    _localInitCompletedTime ??= DateTime.now();
  }

  void markNavDecisionCompleted() {
    _navDecisionCompletedTime ??= DateTime.now();
  }

  void markDashboardDisplayed() {
    _dashboardDisplayedTime ??= DateTime.now();
  }

  void markBackgroundTasksStarted() {
    _backgroundTasksStartedTime ??= DateTime.now();
  }

  void markBackgroundTasksCompleted() {
    _backgroundTasksCompletedTime ??= DateTime.now();
    _printSummary();
  }

  void _printSummary() {
    if (_hasPrintedSummary) return;
    _hasPrintedSummary = true;

    final appStarted = _appStartedTime ?? DateTime.now();
    final backgroundCompleted = _backgroundTasksCompletedTime ?? DateTime.now();
    final totalMs = backgroundCompleted.difference(appStarted).inMilliseconds;

    final logOutput = '''

========== APP STARTUP ==========
App Started
Splash Started
Local Initialization Completed
Navigation Decision Completed
Dashboard Displayed
Background Tasks Started
Background Tasks Completed
Total Startup Time: ${totalMs} ms
=================================
''';

    // Print to standard console output & AppLogger
    debugPrint(logOutput);
    AppLogger.info('Startup timing summary logged (${totalMs}ms)', tag: 'Startup');
  }

  /// Reset timing data (useful for testing or re-login flows)
  void reset() {
    _appStartedTime = null;
    _splashStartedTime = null;
    _localInitCompletedTime = null;
    _navDecisionCompletedTime = null;
    _dashboardDisplayedTime = null;
    _backgroundTasksStartedTime = null;
    _backgroundTasksCompletedTime = null;
    _hasPrintedSummary = false;
  }
}
