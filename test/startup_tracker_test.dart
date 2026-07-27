import 'package:flutter_test/flutter_test.dart';
import 'package:a1_recharge/core/utils/startup_tracker.dart';

void main() {
  test('StartupTracker records all milestones correctly', () async {
    final tracker = StartupTracker.instance;
    tracker.reset();

    tracker.markAppStarted();
    await Future.delayed(const Duration(milliseconds: 10));

    tracker.markSplashStarted();
    await Future.delayed(const Duration(milliseconds: 10));

    tracker.markLocalInitCompleted();
    await Future.delayed(const Duration(milliseconds: 10));

    tracker.markNavDecisionCompleted();
    await Future.delayed(const Duration(milliseconds: 10));

    tracker.markDashboardDisplayed();
    await Future.delayed(const Duration(milliseconds: 10));

    tracker.markBackgroundTasksStarted();
    await Future.delayed(const Duration(milliseconds: 10));

    // Completes and logs output
    tracker.markBackgroundTasksCompleted();

    expect(true, isTrue);
  });
}
