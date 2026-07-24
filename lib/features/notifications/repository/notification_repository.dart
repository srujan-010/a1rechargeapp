import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/logger.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(apiClient: ref.watch(apiClientProvider));
});

class NotificationRepository {
  final ApiClient apiClient;

  NotificationRepository({required this.apiClient});

  Future<void> registerDevice(String token) async {
    try {
      await apiClient.post(
        '/api/notifications/register-device',
        data: {'token': token},
      );
      AppLogger.info('Successfully registered FCM token with backend', tag: 'NotificationRepository');
    } catch (e) {
      AppLogger.error('Failed to register FCM token', tag: 'NotificationRepository', error: e);
      // We don't rethrow here because failing to register token shouldn't break the app flow
    }
  }
}
