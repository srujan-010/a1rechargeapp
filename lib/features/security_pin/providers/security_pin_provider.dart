import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/logger.dart';

class SecurityPinState {
  final bool? securityPinConfigured;
  final bool isAppUnlocked;
  final bool isLocked;
  final DateTime? lockUntil;
  final int failedAttempts;
  final bool isLoading;
  final String? errorMessage;
  final String? resetToken;

  const SecurityPinState({
    this.securityPinConfigured,
    this.isAppUnlocked = false,
    this.isLocked = false,
    this.lockUntil,
    this.failedAttempts = 0,
    this.isLoading = false,
    this.errorMessage,
    this.resetToken,
  });

  SecurityPinState copyWith({
    bool? securityPinConfigured,
    bool? isAppUnlocked,
    bool? isLocked,
    DateTime? lockUntil,
    int? failedAttempts,
    bool? isLoading,
    String? errorMessage,
    String? resetToken,
  }) {
    return SecurityPinState(
      securityPinConfigured: securityPinConfigured ?? this.securityPinConfigured,
      isAppUnlocked: isAppUnlocked ?? this.isAppUnlocked,
      isLocked: isLocked ?? this.isLocked,
      lockUntil: lockUntil ?? this.lockUntil,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      resetToken: resetToken ?? this.resetToken,
    );
  }
}

class SecurityPinNotifier extends StateNotifier<SecurityPinState> {
  final ApiClient _apiClient;
  final Ref _ref;

  SecurityPinNotifier(this._apiClient, this._ref) : super(const SecurityPinState()) {
    fetchStatus();
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  void lockApp() {
    state = state.copyWith(isAppUnlocked: false);
    AppLogger.info('[SECURITY_PIN] Application locked', tag: 'SECURITY_PIN');
  }

  void unlockApp() {
    state = state.copyWith(isAppUnlocked: true, failedAttempts: 0);
    AppLogger.info('[SECURITY_PIN] Application unlocked', tag: 'SECURITY_PIN');
  }

  Future<void> fetchStatus() async {
    final storage = _ref.read(secureStorageProvider);
    final bool localEnabled = await storage.isSecurityPinEnabled();

    try {
      final response = await _apiClient.get(ApiEndpoints.securityPinStatus);
      if (response.success && response.data != null) {
        final Map<String, dynamic> data = response.data is Map<String, dynamic>
            ? (response.data['data'] is Map<String, dynamic> ? response.data['data'] : response.data)
            : {};
        final bool isConfigured = (data['securityPinConfigured'] as bool? ?? false) || localEnabled;
        final bool isLocked = data['isLocked'] as bool? ?? false;
        final int failedAttempts = data['failedAttempts'] as int? ?? 0;
        DateTime? lockUntil;
        if (data['lockUntil'] != null) {
          lockUntil = DateTime.tryParse(data['lockUntil'].toString());
        }

        await storage.setSecurityPinEnabled(enabled: isConfigured);

        state = state.copyWith(
          securityPinConfigured: isConfigured,
          isLocked: isLocked,
          lockUntil: lockUntil,
          failedAttempts: failedAttempts,
        );
        AppLogger.info('[SECURITY_PIN] Security PIN configured: ${isConfigured ? "YES" : "NO"}', tag: 'SECURITY_PIN');
      } else {
        state = state.copyWith(securityPinConfigured: localEnabled);
        AppLogger.info('[SECURITY_PIN] Security PIN configured: ${localEnabled ? "YES" : "NO"}', tag: 'SECURITY_PIN');
      }
    } catch (_) {
      // Fallback to local storage / SessionUser state if status endpoint is offline
      final user = _ref.read(sessionProvider).valueOrNull;
      final bool isConfigured = user?.hasSecurityPin == true || localEnabled;
      state = state.copyWith(securityPinConfigured: isConfigured);
      AppLogger.info('[SECURITY_PIN] Security PIN configured: ${isConfigured ? "YES" : "NO"}', tag: 'SECURITY_PIN');
    }
  }

  Future<bool> createSecurityPin(String pin) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.securityPinCreate,
        data: {'securityPin': pin},
      );
      if (response.success) {
        final storage = _ref.read(secureStorageProvider);
        await storage.saveSecurityPinHash(_hashPin(pin));
        await storage.setSecurityPinEnabled(enabled: true);

        state = state.copyWith(isLoading: false, securityPinConfigured: true);
        unlockApp();
        await fetchStatus();
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: response.message.isNotEmpty ? response.message : 'Failed to create Security PIN',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> verifySecurityPin(String pin) async {
    AppLogger.info('[SECURITY_PIN] Verification started', tag: 'SECURITY_PIN');
    state = state.copyWith(isLoading: true, errorMessage: null);
    final pinHash = _hashPin(pin);
    final storage = _ref.read(secureStorageProvider);

    try {
      final response = await _apiClient.post(
        ApiEndpoints.securityPinVerify,
        data: {'securityPin': pin},
      );

      if (response.success) {
        await storage.saveSecurityPinHash(pinHash);
        await storage.setSecurityPinEnabled(enabled: true);
        state = state.copyWith(isLoading: false, failedAttempts: 0);
        AppLogger.info('[SECURITY_PIN] Verification successful', tag: 'SECURITY_PIN');
        unlockApp();
        return true;
      }

      final newAttempts = state.failedAttempts + 1;
      state = state.copyWith(
        isLoading: false,
        failedAttempts: newAttempts,
        errorMessage: response.message.isNotEmpty ? response.message : 'Incorrect Security PIN',
      );
      AppLogger.info('[SECURITY_PIN] Verification failed', tag: 'SECURITY_PIN');
      return false;
    } catch (e) {
      // Offline fallback verification via secure SHA-256 hash
      final savedHash = await storage.getSecurityPinHash();
      if (savedHash != null && savedHash == pinHash) {
        state = state.copyWith(isLoading: false, failedAttempts: 0);
        AppLogger.info('[SECURITY_PIN] Verification successful (offline)', tag: 'SECURITY_PIN');
        unlockApp();
        return true;
      }

      final newAttempts = state.failedAttempts + 1;
      state = state.copyWith(
        isLoading: false,
        failedAttempts: newAttempts,
        errorMessage: 'Incorrect Security PIN',
      );
      AppLogger.info('[SECURITY_PIN] Verification failed', tag: 'SECURITY_PIN');
      return false;
    }
  }

  Future<bool> changeSecurityPin(String currentPin, String newPin) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.securityPinChange,
        data: {
          'currentSecurityPin': currentPin,
          'newSecurityPin': newPin,
        },
      );
      if (response.success) {
        final storage = _ref.read(secureStorageProvider);
        await storage.saveSecurityPinHash(_hashPin(newPin));
        await storage.setSecurityPinEnabled(enabled: true);
        state = state.copyWith(isLoading: false);
        await fetchStatus();
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: response.message.isNotEmpty ? response.message : 'Failed to change Security PIN',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> sendForgotOtp() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(ApiEndpoints.securityPinForgotSendOtp);
      if (response.success) {
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: response.message.isNotEmpty ? response.message : 'Failed to send OTP',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> verifyForgotOtp(String otp) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.securityPinForgotVerifyOtp,
        data: {'otp': otp},
      );
      if (response.success && response.data != null) {
        final Map<String, dynamic> dataMap = response.data is Map<String, dynamic>
            ? (response.data['data'] is Map<String, dynamic> ? response.data['data'] : response.data)
            : {};
        final token = dataMap['resetToken'] as String?;
        state = state.copyWith(isLoading: false, resetToken: token);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: response.message.isNotEmpty ? response.message : 'Invalid OTP',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> resetSecurityPin(String newPin) async {
    if (state.resetToken == null) {
      state = state.copyWith(errorMessage: 'Reset token missing. Verify OTP again.');
      return false;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.securityPinReset,
        data: {
          'resetToken': state.resetToken,
          'newSecurityPin': newPin,
        },
      );
      if (response.success) {
        final storage = _ref.read(secureStorageProvider);
        await storage.saveSecurityPinHash(_hashPin(newPin));
        await storage.setSecurityPinEnabled(enabled: true);

        state = state.copyWith(isLoading: false, securityPinConfigured: true, resetToken: null);
        unlockApp();
        await fetchStatus();
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: response.message.isNotEmpty ? response.message : 'Failed to reset Security PIN',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final securityPinProvider = StateNotifierProvider<SecurityPinNotifier, SecurityPinState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SecurityPinNotifier(apiClient, ref);
});
