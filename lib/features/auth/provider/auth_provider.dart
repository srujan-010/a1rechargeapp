import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_state.dart';
import '../repository/auth_repository.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/logger.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    authRepository: ref.watch(authRepositoryProvider),
    ref: ref,
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository authRepository;
  final Ref ref;

  AuthNotifier({required this.authRepository, required this.ref})
      : super(const AuthState.initial());

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
}
