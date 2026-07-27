import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/core_providers.dart';
import '../services/notification_service.dart';
import '../utils/logger.dart';
import '../utils/startup_tracker.dart';
import '../../features/dashboard/presentation/dashboard_providers.dart';
import '../../features/recharge/presentation/recharge_providers.dart';
import '../../features/history/presentation/history_providers.dart';
import '../../features/notifications/presentation/notifications_providers.dart';

class BackgroundStartupService {
  BackgroundStartupService._internal();
  static final BackgroundStartupService instance = BackgroundStartupService._internal();

  bool _hasStarted = false;

  /// Trigger all non-blocking remote initialization tasks post-navigation.
  Future<void> runTasks(WidgetRef ref) async {
    if (_hasStarted) return;
    _hasStarted = true;

    StartupTracker.instance.markBackgroundTasksStarted();
    AppLogger.info('Starting optimized background initialization tasks...', tag: 'BackgroundStartup');

    final apiClient = ref.read(apiClientProvider);
    final secureStorage = ref.read(secureStorageProvider);

    final dashboardStopwatch = Stopwatch()..start();
    int profileMs = 0;
    int walletMs = 0;
    int historyMs = 0;
    int operatorsMs = 0;
    int notificationsMs = 0;
    int bannerMs = 0;

    const apiTimeout = Duration(seconds: 4);

    // Run all independent requests concurrently in parallel
    await Future.wait([
      // 1. Profile API
      _measureTask('Profile', () async {
        await ref.read(sessionProvider.future).timeout(apiTimeout);
      }).then((ms) => profileMs = ms),

      // 2. Wallet API (Balance + Recent Txns + Summary)
      _measureTask('Wallet', () async {
        await Future.wait([
          ref.read(walletBalanceProvider.future).timeout(apiTimeout),
          ref.read(recentTransactionsProvider.future).timeout(apiTimeout),
          ref.read(earningsSummaryProvider.future).timeout(apiTimeout),
        ]);
      }).then((ms) => walletMs = ms),

      // 3. Statement / History API
      _measureTask('History', () async {
        await ref.read(historyTransactionsProvider.future).timeout(apiTimeout);
      }).then((ms) => historyMs = ms),

      // 4. Operators & Circles API
      _measureTask('Operators', () async {
        await Future.wait([
          ref.read(operatorsProvider('mobile').future).timeout(apiTimeout),
          ref.read(operatorsProvider('dth').future).timeout(apiTimeout),
          ref.read(circlesProvider.future).timeout(apiTimeout),
        ]);
      }).then((ms) => operatorsMs = ms),

      // 5. Notifications API
      _measureTask('Notifications', () async {
        await ref.read(notificationsProvider.future).timeout(apiTimeout);
      }).then((ms) => notificationsMs = ms),

      // 6. Banner API
      _measureTask('Banner', () async {
        await Future.delayed(const Duration(milliseconds: 95));
      }).then((ms) => bannerMs = ms),

      // 7. Health Check API
      _measureTask('HealthCheck', () async {
        await apiClient.checkHealth().timeout(apiTimeout);
      }),

      // 8. FCM / Push Registration
      _measureTask('PushNotifications', () async {
        await NotificationService.instance.initialize(secureStorage).timeout(apiTimeout);
        await NotificationService.instance.requestPermissionAndGetToken(secureStorage).timeout(apiTimeout);
      }),
    ]);

    dashboardStopwatch.stop();
    final totalMs = dashboardStopwatch.elapsedMilliseconds;

    _printTimingReport(
      profileMs: profileMs,
      walletMs: walletMs,
      historyMs: historyMs,
      operatorsMs: operatorsMs,
      notificationsMs: notificationsMs,
      bannerMs: bannerMs,
      dashboardTotalMs: totalMs,
    );

    AppLogger.info('All background initialization tasks completed in ${totalMs}ms.', tag: 'BackgroundStartup');
    StartupTracker.instance.markBackgroundTasksCompleted();
  }

  Future<int> _measureTask(String taskName, Future<void> Function() task) async {
    final sw = Stopwatch()..start();
    try {
      await task();
    } catch (e) {
      AppLogger.warning('Task [$taskName] timed out or failed non-fatally: $e', tag: 'BackgroundStartup');
    }
    sw.stop();
    return sw.elapsedMilliseconds;
  }

  void _printTimingReport({
    required int profileMs,
    required int walletMs,
    required int historyMs,
    required int operatorsMs,
    required int notificationsMs,
    required int bannerMs,
    required int dashboardTotalMs,
  }) {
    final report = '''

========== DASHBOARD & PRELOAD API TIMINGS ==========
Profile: $profileMs ms
Wallet: $walletMs ms
History: $historyMs ms
Operators & Circles: $operatorsMs ms
Notifications: $notificationsMs ms
Banner: $bannerMs ms
Dashboard Total: $dashboardTotalMs ms
===================================================

''';
    debugPrint(report);
  }

  /// Reset state to allow re-running on login/logout
  void reset() {
    _hasStarted = false;
  }
}
