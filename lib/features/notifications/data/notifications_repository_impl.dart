import '../../../core/models/app_exception.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/result.dart';
import '../domain/models/app_notification.dart';
import '../domain/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<Result<List<AppNotification>, AppException>> getNotifications({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.get<List<AppNotification>>(
        '/notifications?page=$page&limit=$limit',
        fromJson: (json) {
          if (json == null) return [];
          final list = json as List<dynamic>;
          return list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
        },
      );

      if (response.success && response.data != null) {
        return Success(response.data!);
      } else {
        return Failure(ServerException(message: response.message ?? 'Failed to fetch notifications'));
      }
    } catch (e) {
      return Failure(ServerException(message: e.toString()));
    }
  }

  @override
  Future<Result<void, AppException>> markAsRead(String notificationId) async {
    try {
      final response = await _apiClient.patch<dynamic>(
        '/notifications/$notificationId/read',
      );
      if (response.success) {
        return const Success(null);
      } else {
        return Failure(ServerException(message: response.message ?? 'Failed to mark as read'));
      }
    } catch (e) {
      return Failure(ServerException(message: e.toString()));
    }
  }

  @override
  Future<Result<void, AppException>> markAllAsRead() async {
    try {
      final response = await _apiClient.patch<dynamic>(
        '/notifications/read-all',
      );
      if (response.success) {
        return const Success(null);
      } else {
        return Failure(ServerException(message: response.message ?? 'Failed to mark all as read'));
      }
    } catch (e) {
      return Failure(ServerException(message: e.toString()));
    }
  }
}
