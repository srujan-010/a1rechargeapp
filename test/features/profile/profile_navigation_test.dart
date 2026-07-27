import 'package:flutter_test/flutter_test.dart';
import 'package:a1_recharge/core/constants/route_names.dart';

void main() {
  test('RouteNames.notificationSettings and RouteNames.notifications match /notifications', () {
    expect(RouteNames.notifications, '/notifications');
    expect(RouteNames.notificationSettings, RouteNames.notifications);
  });
}
