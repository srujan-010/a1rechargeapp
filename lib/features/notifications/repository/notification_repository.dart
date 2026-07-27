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
      print('\n========== FCM DEBUG ==========');
      print('HTTP Request: POST /api/notifications/register-device');
      print('Payload: {"token": "$token"}');
      
      final response = await apiClient.post(
        '/api/notifications/register-device',
        data: {'token': token},
      );
      
      print('HTTP Response Success: ${response.success}');
      print('HTTP Response Message: ${response.message}');
      print('HTTP Response Data: ${response.data}');
      print('==============================\n');
      
      AppLogger.info('Successfully registered FCM token with backend', tag: 'NotificationRepository');
    } catch (e) {
      print('\n========== FCM DEBUG ==========');
      print('HTTP Error: $e');
      print('==============================\n');
      AppLogger.error('Failed to register FCM token', tag: 'NotificationRepository', error: e);
      throw e; // We must throw so the retry loop in auth_provider can catch it
    }
  }
}
