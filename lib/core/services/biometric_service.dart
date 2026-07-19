// lib/core/services/biometric_service.dart
// Biometric authentication service using local_auth.
// Always checks device capability before attempting authentication.
// Falls back to MPIN if biometrics are unavailable — never locks the user out.

import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';
import '../utils/logger.dart';

enum BiometricCapability { available, unavailable, notEnrolled, notSupported }

enum BiometricAuthResult { success, failure, fallbackRequired, cancelled }

class BiometricService {
  BiometricService() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  /// Checks if biometric authentication is available on this device.
  Future<BiometricCapability> checkCapability() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();

      if (!isDeviceSupported) return BiometricCapability.notSupported;
      if (!canCheck) return BiometricCapability.notEnrolled;

      final biometrics = await _auth.getAvailableBiometrics();
      if (biometrics.isEmpty) return BiometricCapability.notEnrolled;

      return BiometricCapability.available;
    } on PlatformException catch (e) {
      AppLogger.warning(
        'Biometric capability check failed',
        tag: 'Biometric',
        error: e,
      );
      return BiometricCapability.unavailable;
    }
  }

  /// Returns available biometric types (fingerprint, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Authenticate with biometrics.
  /// Returns [BiometricAuthResult.fallbackRequired] if biometrics fail
  /// and the caller should show MPIN entry.
  Future<BiometricAuthResult> authenticate({
    String reason = 'Please authenticate to continue',
  }) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,  // allow device PIN as secondary fallback
          stickyAuth: true,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );

      AppLogger.info(
        'Biometric auth result: $authenticated',
        tag: 'Biometric',
      );
      return authenticated
          ? BiometricAuthResult.success
          : BiometricAuthResult.fallbackRequired;
    } on PlatformException catch (e) {
      AppLogger.warning(
        'Biometric auth exception: ${e.code}',
        tag: 'Biometric',
        error: e,
      );

      switch (e.code) {
        case auth_error.notAvailable:
        case auth_error.notEnrolled:
        case auth_error.passcodeNotSet:
          return BiometricAuthResult.fallbackRequired;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return BiometricAuthResult.fallbackRequired;
        default:
          return BiometricAuthResult.cancelled;
      }
    }
  }

  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } on PlatformException catch (e) {
      AppLogger.warning('stopAuthentication failed', tag: 'Biometric', error: e);
    }
  }
}
