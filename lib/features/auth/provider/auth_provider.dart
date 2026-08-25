import 'dart:async';
import 'package:flutter/foundation.dart';
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
    _initSessionListener();
  }

  StreamSubscription? _tokenRefreshSub;

  void _initSessionListener() {
    // Listen for 401 unauthorized signals to log out user
    _tokenRefreshSub?.cancel();
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> sendOtp(String phoneNumber) async {
    state = const AuthState.loading();
    try {
      AppLogger.info('Send OTP Started: $phoneNumber', tag: 'Auth');
      await authRepository.sendOtp(phoneNumber);
      state = AuthState.codeSent(phone: phoneNumber);
    } catch (e, stack) {
      AppLogger.error('sendOtp Failed', tag: 'Auth', error: e, stackTrace: stack);
      state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> verifyOtpAndLogin({
    required String phone,
    required String smsCode,
  }) async {
    state = const AuthState.loading();
    AppLogger.info('====================================================', tag: 'Auth');
    AppLogger.info('Verify OTP Started: Phone=$phone', tag: 'Auth');
    AppLogger.info('API Request: POST /auth/verify-otp with mobile & code', tag: 'Auth');
    
    try {
      final response = await authRepository.verifyOtpAndLogin(
        phone: phone,
        smsCode: smsCode,
      );

      AppLogger.info('API Response Success: isNewUser=${response.isNewUser}', tag: 'Auth');

      if (response.isNewUser) {
        AppLogger.info('Authentication Response: Registration Required', tag: 'Auth');
        AppLogger.info('Navigation: Pushing Registration Screen', tag: 'Auth');
        state = AuthState.registrationRequired(
          phone: response.phone ?? phone,
          tempSessionToken: response.tempSessionToken ?? '',
        );
      } else {
        AppLogger.info('Authentication Response: User Authenticated', tag: 'Auth');
        AppLogger.info('Token Save: JWT Token saved to Secure Storage', tag: 'Auth');
        ref.invalidate(hasValidJwtProvider);
        if (response.user != null) {
          await ref.read(sessionProvider.notifier).saveUser(response.user!);
        } else {
          ref.invalidate(sessionProvider);
        }

        AppLogger.info('FCM Initialization Started', tag: 'Auth');
        await _registerFcmToken();

        AppLogger.info('Navigation: Navigating to Dashboard', tag: 'Auth');
        state = const AuthState.authenticated();
      }
      AppLogger.info('====================================================', tag: 'Auth');
    } catch (e, stack) {
      AppLogger.error('verifyOtpAndLogin Failed', tag: 'Auth', error: e, stackTrace: stack);
      AppLogger.error('Stack Trace:\n$stack', tag: 'Auth');
      AppLogger.info('====================================================', tag: 'Auth');
      state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> resendOtp(String phone) async {
    try {
      await authRepository.resendOtp(phone);
      AppLogger.info('Resent OTP successfully', tag: 'Auth');
    } catch (e, stack) {
      AppLogger.error('resendOtp Failed', tag: 'Auth', error: e, stackTrace: stack);
      state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> submitRegistration({
    required String tempSessionToken,
    required String name,
    String accountType = 'RETAILER',
    String? shopName,
    bool? hasPhysicalShop,
    String? businessType,
    String? address,
    String? email,
    String? state,
    String? district,
    String? pincode,
    String? referralCode,
    bool termsAccepted = true,
  }) async {
    this.state = const AuthState.loading();
    try {
      await authRepository.registerRetailer(
        tempSessionToken: tempSessionToken,
        name: name,
        accountType: accountType,
        shopName: shopName,
        hasPhysicalShop: hasPhysicalShop,
        businessType: businessType,
        address: address,
        email: email,
        state: state,
        district: district,
        pincode: pincode,
        referralCode: referralCode,
        termsAccepted: termsAccepted,
      );
      ref.invalidate(sessionProvider);
      await _registerFcmToken();
      this.state = const AuthState.authenticated();
    } catch (e, stack) {
      AppLogger.error('submitRegistration Failed', tag: 'Auth', error: e, stackTrace: stack);
      this.state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    AppLogger.info('Logout Provider: Auth state before reset: ${state.runtimeType}', tag: 'Auth');
    state = const AuthState.loading();
    
    await authRepository.logout();
    
    ref.invalidate(hasValidJwtProvider);
    ref.invalidate(sessionProvider);
    
    state = const AuthState.initial();
    AppLogger.info('Logout Provider: Auth state after reset: ${state.runtimeType}', tag: 'Auth');
  }

  Future<void> _registerFcmToken() async {
    if (kIsWeb) {
      AppLogger.info('FCM Initialization Bypassed for Web Platform', tag: 'Auth');
      return;
    }
    try {
      final secureStorage = ref.read(secureStorageProvider);
      final token = await NotificationService.instance.requestPermissionAndGetToken(secureStorage);

      if (token != null) {
        int retryCount = 0;
        bool success = false;
        while (retryCount < 3 && !success) {
          try {
            await notificationRepository.registerDevice(token);
            success = true;
            AppLogger.info('FCM Initialization Success: FCM Token uploaded', tag: 'Auth');
          } catch (e) {
            retryCount++;
            AppLogger.warning('Failed to upload FCM token. Retry $retryCount of 3', tag: 'Auth', error: e);
            if (retryCount < 3) {
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        }
      } else {
        AppLogger.info('FCM Initialization Skipped: Token is null', tag: 'Auth');
      }
    } catch (e, stack) {
      AppLogger.error('FCM Initialization Failed (Ignored to keep Login flow uninterrupted)', tag: 'Auth', error: e, stackTrace: stack);
    }
  }
}
