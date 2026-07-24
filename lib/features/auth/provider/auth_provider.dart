import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_state.dart';
import '../repository/auth_repository.dart';
import '../../notifications/repository/notification_repository.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/notification_service.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    authRepository: ref.watch(authRepositoryProvider),
    notificationRepository: ref.watch(notificationRepositoryProvider),
    ref: ref,
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository authRepository;
  final NotificationRepository notificationRepository;
  final Ref ref;

  AuthNotifier({
    required this.authRepository,
    required this.notificationRepository,
    required this.ref,
  }) : super(const AuthState.initial()) {
    _initTokenRefreshListener();
  }

  StreamSubscription<String>? _tokenRefreshSub;

  void _initTokenRefreshListener() {
    _tokenRefreshSub = NotificationService.instance.onTokenRefresh.listen((newToken) async {
      // Only upload if currently authenticated
      if (state is AuthStateAuthenticated) {
        AppLogger.info('FCM Token Refreshed while authenticated, re-uploading...', tag: 'Auth');
        try {
          await notificationRepository.registerDevice(newToken);
          AppLogger.info('Refreshed FCM token uploaded successfully', tag: 'Auth');
        } catch (e) {
          AppLogger.error('Failed to upload refreshed FCM token', tag: 'Auth', error: e);
        }
      }
    });
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> sendOtp(String phoneNumber) async {
    state = const AuthState.loading();
    try {
      await authRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (Android)
          try {
            state = const AuthState.loading();
            final response = await authRepository.loginWithCredential(credential);
            if (response.isNewUser) {
              state = AuthState.registrationRequired(
                phone: response.phone ?? '',
                firebaseUid: response.firebaseUid ?? '',
              );
            } else {
              ref.invalidate(sessionProvider);
              await _registerFcmToken();
              state = const AuthState.authenticated();
            }
          } catch (e, stack) {
            AppLogger.error('Firebase Auto-Resolution Failed', tag: 'Auth', error: e, stackTrace: stack);
            state = AuthState.error(e.toString());
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          state = AuthState.error(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          state = AuthState.codeSent(
            verificationId: verificationId,
            resendToken: resendToken,
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // You could handle timeout state if needed
        },
      );
    } catch (e, stack) {
      AppLogger.error('sendOtp Failed', tag: 'Auth', error: e, stackTrace: stack);
      state = AuthState.error(e.toString());
    }
  }

  Future<void> verifyOtpAndLogin({
    required String verificationId,
    required String smsCode,
  }) async {
    state = const AuthState.loading();
    try {
      final response = await authRepository.verifyOtpAndLogin(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      if (response.isNewUser) {
        state = AuthState.registrationRequired(
          phone: response.phone ?? '',
          firebaseUid: response.firebaseUid ?? '',
        );
      } else {
        ref.invalidate(sessionProvider);
        await _registerFcmToken();
        state = const AuthState.authenticated();
      }
    } catch (e, stack) {
      AppLogger.error('verifyOtpAndLogin Failed', tag: 'Auth', error: e, stackTrace: stack);
      state = AuthState.error(e.toString());
    }
  }

  Future<void> submitRegistration(Map<String, dynamic> formData) async {
    state = const AuthState.loading();
    try {
      await authRepository.registerRetailer(formData);
      ref.invalidate(sessionProvider);
      await _registerFcmToken();
      state = const AuthState.authenticated();
    } catch (e, stack) {
      AppLogger.error('submitRegistration Failed', tag: 'Auth', error: e, stackTrace: stack);
      state = AuthState.error(e.toString());
    }
  }

  Future<void> logout() async {
    state = const AuthState.loading();
    await authRepository.logout();
    ref.invalidate(sessionProvider);
    state = const AuthState.initial();
  }

  Future<void> _registerFcmToken() async {
    try {
      final secureStorage = ref.read(secureStorageProvider);
      
      // Request permission on Android 13+ (or iOS), then get token
      final token = await NotificationService.instance.requestPermissionAndGetToken(secureStorage);
      
      if (token != null) {
        // Retry logic for token upload
        int retryCount = 0;
        bool success = false;
        while (retryCount < 3 && !success) {
          try {
            AppLogger.info('Uploading FCM token to backend (Attempt ${retryCount + 1})...', tag: 'Auth');
            await notificationRepository.registerDevice(token);
            success = true;
            AppLogger.info('FCM token uploaded successfully', tag: 'Auth');
          } catch (e) {
            retryCount++;
            AppLogger.warning('Failed to upload FCM token. Retry $retryCount of 3', tag: 'Auth', error: e);
            if (retryCount < 3) {
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        }
      } else {
        AppLogger.warning('FCM token is null, cannot register with backend', tag: 'Auth');
      }
    } catch (e, stack) {
      AppLogger.error('Error during FCM token registration', tag: 'Auth', error: e, stackTrace: stack);
    }
  }
}
