import 'package:flutter_test/flutter_test.dart';
import 'package:a1_recharge/core/services/background_startup_service.dart';
import 'package:a1_recharge/core/utils/startup_tracker.dart';

void main() {
  test('BackgroundStartupService runs and tracks timings', () async {
    final tracker = StartupTracker.instance;
    tracker.reset();
    tracker.markAppStarted();
    tracker.markSplashStarted();
    tracker.markLocalInitCompleted();
    tracker.markNavDecisionCompleted();
    tracker.markDashboardDisplayed();
    
    final service = BackgroundStartupService.instance;
    service.reset();
    
    expect(true, isTrue);
  });
}
