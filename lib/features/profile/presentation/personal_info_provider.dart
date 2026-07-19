import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';

final personalInfoProvider = StateNotifierProvider<PersonalInfoNotifier, AsyncValue<void>>((ref) {
  return PersonalInfoNotifier(ref);
});

class PersonalInfoNotifier extends StateNotifier<AsyncValue<void>> {
  PersonalInfoNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      state = const AsyncValue.loading();
      final apiClient = ref.read(apiClientProvider);
      
      final response = await apiClient.put<Map<String, dynamic>>(
        '/user/profile',
        data: updates,
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success) {
        // Refresh session
        ref.invalidate(sessionProvider);
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(response.message ?? 'Update failed', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }

  Future<void> uploadAvatar(File imageFile) async {
    try {
      state = const AsyncValue.loading();
      final apiClient = ref.read(apiClientProvider);
      
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(imageFile.path),
      });

      final response = await apiClient.post<Map<String, dynamic>>(
        '/user/profile/avatar',
        data: formData,
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success) {
        ref.invalidate(sessionProvider);
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(response.message ?? 'Upload failed', StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }
}
