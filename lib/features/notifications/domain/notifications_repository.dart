import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import 'models/app_notification.dart';

abstract class NotificationsRepository {
  Future<Result<List<AppNotification>, AppException>> getNotifications({int page = 1, int limit = 20});
  Future<Result<void, AppException>> markAsRead(String notificationId);
  Future<Result<void, AppException>> markAllAsRead();
}
