import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/msg91_auth_repository.dart';
import '../../../core/providers/core_providers.dart';

final msg91AuthRepositoryProvider = Provider<Msg91AuthRepository>((ref) {
  return Msg91AuthRepository(apiClient: ref.watch(apiClientProvider));
});

class Msg91AuthState {
  final bool isLoading;
  final String? error;
  final bool isOtpSent;
  final bool isVerified;
  final bool isNewUser;
  final String? mobile;
  final String? tempSessionToken;

  Msg91AuthState({
    this.isLoading = false,
    this.error,
    this.isOtpSent = false,
    this.isVerified = false,
    this.isNewUser = false,
    this.mobile,
    this.tempSessionToken,
  });

  Msg91AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isOtpSent,
    bool? isVerified,
    bool? isNewUser,
    String? mobile,
    String? tempSessionToken,
  }) {
    return Msg91AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isVerified: isVerified ?? this.isVerified,
      isNewUser: isNewUser ?? this.isNewUser,
      mobile: mobile ?? this.mobile,
      tempSessionToken: tempSessionToken ?? this.tempSessionToken,
    );
  }
}

class Msg91AuthNotifier extends StateNotifier<Msg91AuthState> {
  final Msg91AuthRepository _repository;
  final Ref _ref;

  Msg91AuthNotifier(this._repository, this._ref) : super(Msg91AuthState());

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.sendOtp(phone);
      state = state.copyWith(isLoading: false, isOtpSent: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.verifyOtp(phone, otp);
      if (response['success'] == true) {
        final data = response['data'];
        final token = data['accessToken'] ?? data['token'];
        
        if (token != null) {
          final secureStorage = _ref.read(secureStorageProvider);
          await secureStorage.saveTokens(
            accessToken: token,
            refreshToken: data['refreshToken'] ?? '',
            expiry: DateTime.now().add(const Duration(days: 30)),
          );
          _ref.invalidate(sessionProvider);
        }
        
        state = state.copyWith(isLoading: false, isVerified: true);
      } else {
        state = state.copyWith(isLoading: false, error: 'Verification failed');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> verifyAccessToken(String accessToken) async {
    debugPrint('[MSG91 Provider] verifyAccessToken() called.');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.loginWithAccessToken(accessToken);
      
      if (response['success'] == true) {
        if (response['isNewUser'] == true) {
           debugPrint('[MSG91 Provider] User is new. Proceeding to registration.');
           state = state.copyWith(
             isLoading: false,
             isNewUser: true,
             mobile: response['mobile'],
             tempSessionToken: response['tempSessionToken'],
           );
           return;
        }
        
        final token = response['token'] ?? response['data']?['accessToken'];
        if (token != null) {
          final secureStorage = _ref.read(secureStorageProvider);
          await secureStorage.saveTokens(
            accessToken: token,
            refreshToken: '',
            expiry: DateTime.now().add(const Duration(days: 30)),
          );
          _ref.invalidate(sessionProvider);
        }
        state = state.copyWith(isLoading: false, isVerified: true);
      } else {
        final msg = response['message'] ?? 'Authentication failed';
        state = state.copyWith(isLoading: false, error: msg);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final msg91AuthProvider = StateNotifierProvider<Msg91AuthNotifier, Msg91AuthState>((ref) {
  return Msg91AuthNotifier(ref.read(msg91AuthRepositoryProvider), ref);
});
