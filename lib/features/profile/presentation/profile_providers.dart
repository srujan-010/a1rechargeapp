import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/secure_storage_service.dart';

final biometricStateProvider = StateNotifierProvider<BiometricNotifier, bool>((ref) {
  return BiometricNotifier(ref.watch(secureStorageProvider));
});

class BiometricNotifier extends StateNotifier<bool> {
  final SecureStorageService _storage;
  final BiometricService _biometricService = BiometricService();

  BiometricNotifier(this._storage) : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await _storage.isBiometricEnabled();
    state = enabled;
  }

  /// Toggles biometric login status.
  /// Returns an error message String if unsupported/failed, or null on success.
  Future<String?> toggleBiometric(bool enable) async {
    if (!enable) {
      await _storage.setBiometricEnabled(enabled: false);
      state = false;
      return null;
    }

    // Check device / browser capability
    final capability = await _biometricService.checkCapability();
    if (capability != BiometricCapability.available) {
      state = false;
      return "Biometric authentication is not available on this device/browser.";
    }

    // Prompt user authentication
    final result = await _biometricService.authenticate(
      reason: 'Authenticate to enable Biometric Login for A1 Recharge',
    );

    if (result == BiometricAuthResult.success) {
      await _storage.setBiometricEnabled(enabled: true);
      state = true;
      return null;
    } else {
      state = false;
      return "Biometric authentication failed. Biometric login remains disabled.";
    }
  }
}
