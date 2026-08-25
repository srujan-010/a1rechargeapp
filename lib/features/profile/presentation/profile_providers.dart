import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/utils/logger.dart';

final biometricStateProvider = StateNotifierProvider<BiometricNotifier, bool>((ref) {
  return BiometricNotifier(ref.watch(secureStorageProvider));
});

class BiometricNotifier extends StateNotifier<bool> {
  final SecureStorageService _storage;
  final BiometricService _biometricService = BiometricService();
  bool _isProcessing = false;

  BiometricNotifier(this._storage) : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await _storage.isBiometricEnabled();
    state = enabled;
  }

  /// Toggles biometric login status.
  /// Returns an error message String if unsupported/failed, or null on success or cancelled.
  Future<String?> toggleBiometric(bool enable) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      AppLogger.info('[BIOMETRIC] Toggle changed', tag: 'Biometric');

      if (!enable) {
        await _storage.setBiometricEnabled(enabled: false);
        AppLogger.info('[BIOMETRIC] Biometric login state saved', tag: 'Biometric');
        state = false;
        return null;
      }

      // Check device capability
      AppLogger.info('[BIOMETRIC] Device capability checked', tag: 'Biometric');
      final capability = await _biometricService.checkCapability();
      if (capability != BiometricCapability.available) {
        await _storage.setBiometricEnabled(enabled: false);
        AppLogger.info('[BIOMETRIC] Biometric login state saved', tag: 'Biometric');
        state = false;
        return "Biometric authentication is not available on this device.";
      }

      // Prompt user authentication
      AppLogger.info('[BIOMETRIC] Authentication requested', tag: 'Biometric');
      final result = await _biometricService.authenticate(
        reason: 'Authenticate to enable Biometric Login for A1 Recharge',
      );

      if (result == BiometricAuthResult.success) {
        AppLogger.info('[BIOMETRIC] Authentication successful', tag: 'Biometric');
        await _storage.setBiometricEnabled(enabled: true);
        AppLogger.info('[BIOMETRIC] Biometric login state saved', tag: 'Biometric');
        state = true;
        return null;
      } else if (result == BiometricAuthResult.cancelled) {
        AppLogger.info('[BIOMETRIC] Authentication cancelled', tag: 'Biometric');
        await _storage.setBiometricEnabled(enabled: false);
        AppLogger.info('[BIOMETRIC] Biometric login state saved', tag: 'Biometric');
        state = false;
        return null; // Cancellation is not an alarming error
      } else {
        AppLogger.info('[BIOMETRIC] Authentication failed', tag: 'Biometric');
        await _storage.setBiometricEnabled(enabled: false);
        AppLogger.info('[BIOMETRIC] Biometric login state saved', tag: 'Biometric');
        state = false;
        return "Biometric authentication failed. Biometric login remains disabled.";
      }
    } finally {
      _isProcessing = false;
    }
  }
}
