import 'package:flutter_test/flutter_test.dart';
import 'package:a1_recharge/features/notifications/domain/models/app_notification.dart';

void main() {
  test('AppNotification creates and parses correctly', () {
    final notif = AppNotification(
      id: 'n1',
      title: 'Mobile Recharge Successful',
      message: 'Recharge of Rs.299 for 9876543210 is successful.',
      category: NotificationCategory.success,
      priority: NotificationPriority.normal,
      isRead: false,
      timestamp: DateTime.now(),
    );

    expect(notif.id, 'n1');
    expect(notif.isRead, false);

    final updated = notif.copyWith(isRead: true);
    expect(updated.isRead, true);
  });
}
