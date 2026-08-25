import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/utils/logger.dart';

class BiometricState {
  final bool isEnabled;
  final bool isProcessing;

  const BiometricState({
    required this.isEnabled,
    this.isProcessing = false,
  });

  BiometricState copyWith({
    bool? isEnabled,
    bool? isProcessing,
  }) {
    return BiometricState(
      isEnabled: isEnabled ?? this.isEnabled,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

final biometricStateProvider = StateNotifierProvider<BiometricNotifier, BiometricState>((ref) {
  return BiometricNotifier(ref.watch(secureStorageProvider));
});

class BiometricNotifier extends StateNotifier<BiometricState> {
  final SecureStorageService _storage;
  final BiometricService _biometricService = BiometricService();

  BiometricNotifier(this._storage) : super(const BiometricState(isEnabled: false)) {
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await _storage.isBiometricEnabled();
    state = BiometricState(isEnabled: enabled, isProcessing: false);
  }

  /// Toggles biometric login status.
  /// Returns an error message String if unsupported/failed, or null on success or cancelled.
  Future<String?> toggleBiometric(bool enable) async {
    if (state.isProcessing) {
      AppLogger.info('[Biometric] Toggle ignored: already processing', tag: 'Biometric');
      return null;
    }

    state = state.copyWith(isProcessing: true);
    AppLogger.info('[Biometric] Toggle requested: ${enable ? "ON" : "OFF"}', tag: 'Biometric');

    try {
      if (kIsWeb) {
        AppLogger.info('[Biometric] Web platform -> Biometric disabled', tag: 'Biometric');
        await _storage.setBiometricEnabled(enabled: false);
        state = const BiometricState(isEnabled: false, isProcessing: false);
        return "Biometric login is available in the Android/iOS app.";
      }

      if (!enable) {
        // Disable flow: update storage & state directly without biometric prompt
        await _storage.setBiometricEnabled(enabled: false);
        AppLogger.info('[Biometric] Biometric login DISABLED', tag: 'Biometric');
        state = const BiometricState(isEnabled: false, isProcessing: false);
        return null;
      }

      // Enable flow: Check device support & capability
      AppLogger.info('[Biometric] Checking device support & capability', tag: 'Biometric');
      final capability = await _biometricService.checkCapability();

      if (capability == BiometricCapability.notEnrolled) {
        AppLogger.warning('[Biometric] Device not enrolled', tag: 'Biometric');
        await _storage.setBiometricEnabled(enabled: false);
        state = const BiometricState(isEnabled: false, isProcessing: false);
        return "Set up fingerprint or face unlock in your device settings to enable biometric login.";
      } else if (capability == BiometricCapability.notSupported) {
        AppLogger.warning('[Biometric] Device not supported', tag: 'Biometric');
        await _storage.setBiometricEnabled(enabled: false);
        state = const BiometricState(isEnabled: false, isProcessing: false);
        return "Biometric authentication is not available on this device.";
      } else if (capability == BiometricCapability.unavailable) {
        AppLogger.warning('[Biometric] Hardware unavailable', tag: 'Biometric');
        await _storage.setBiometricEnabled(enabled: false);
        state = const BiometricState(isEnabled: false, isProcessing: false);
        return "Biometric hardware is currently unavailable on this device.";
      }

      // Launch native biometric authentication prompt
      AppLogger.info('[Biometric] Starting authentication prompt', tag: 'Biometric');
      final result = await _biometricService.authenticate(
        reason: 'Authenticate to enable biometric login',
      );

      if (result == BiometricAuthResult.success) {
        AppLogger.info('[Biometric] Authentication result: true', tag: 'Biometric');
        AppLogger.info('[Biometric] Saving biometric preference: true', tag: 'Biometric');
        await _storage.setBiometricEnabled(enabled: true);
        AppLogger.info('[Biometric] Biometric login ENABLED', tag: 'Biometric');
        state = const BiometricState(isEnabled: true, isProcessing: false);
        return null;
      } else if (result == BiometricAuthResult.cancelled) {
        AppLogger.info('[Biometric] User cancelled prompt. biometricEnabled remains false', tag: 'Biometric');
        await _storage.setBiometricEnabled(enabled: false);
        state = const BiometricState(isEnabled: false, isProcessing: false);
        return null; // Silent cancellation
      } else {
        AppLogger.warning('[Biometric] Authentication failed. biometricEnabled remains false', tag: 'Biometric');
        await _storage.setBiometricEnabled(enabled: false);
        state = const BiometricState(isEnabled: false, isProcessing: false);
        return "Biometric authentication failed.";
      }
    } catch (e) {
      AppLogger.error('[Biometric] Unexpected toggle error: $e', tag: 'Biometric');
      await _storage.setBiometricEnabled(enabled: false);
      state = const BiometricState(isEnabled: false, isProcessing: false);
      return "Biometric login couldn't be enabled. Please try again.";
    }
  }
}
