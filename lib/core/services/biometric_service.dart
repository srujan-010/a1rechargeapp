// lib/core/services/biometric_service.dart
// Biometric authentication service using local_auth.
// Always checks device capability before attempting authentication.
// Web safe to avoid MissingPluginException on browsers.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import '../utils/logger.dart';

enum BiometricCapability { available, unavailable, notEnrolled, notSupported }

enum BiometricAuthResult { success, failure, fallbackRequired, cancelled, notSupported }

class BiometricService {
  BiometricService() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  /// Checks if biometric authentication is available on this device.
  Future<BiometricCapability> checkCapability() async {
    if (kIsWeb) {
      AppLogger.info('[Biometric] Platform: web -> returning notSupported', tag: 'Biometric');
      return BiometricCapability.notSupported;
    }

    try {
      AppLogger.info('[Biometric] Platform: ${defaultTargetPlatform.name}', tag: 'Biometric');
      AppLogger.info('[Biometric] Checking device support...', tag: 'Biometric');
      
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      
      AppLogger.info('[Biometric] Device supported: $isDeviceSupported', tag: 'Biometric');
      AppLogger.info('[Biometric] Can check biometrics: $canCheck', tag: 'Biometric');

      if (!isDeviceSupported) return BiometricCapability.notSupported;
      if (!canCheck) return BiometricCapability.notEnrolled;

      final biometrics = await _auth.getAvailableBiometrics();
      AppLogger.info('[Biometric] Available biometrics: $biometrics', tag: 'Biometric');

      if (biometrics.isEmpty) return BiometricCapability.notEnrolled;

      return BiometricCapability.available;
    } on PlatformException catch (e) {
      AppLogger.warning(
        '[Biometric] Capability check failed: ${e.code} - ${e.message}',
        tag: 'Biometric',
        error: e,
      );
      return BiometricCapability.unavailable;
    } catch (e) {
      AppLogger.warning('[Biometric] Unexpected capability check error: $e', tag: 'Biometric');
      return BiometricCapability.unavailable;
    }
  }

  /// Returns available biometric types (fingerprint, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Authenticate with biometrics.
  Future<BiometricAuthResult> authenticate({
    String reason = 'Authenticate to enable biometric login',
  }) async {
    if (kIsWeb) {
      AppLogger.info('[Biometric] Web platform -> skipping native auth', tag: 'Biometric');
      return BiometricAuthResult.notSupported;
    }

    try {
      AppLogger.info('[Biometric] Starting native authentication prompt...', tag: 'Biometric');
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );

      AppLogger.info(
        '[Biometric] Authentication result: $authenticated',
        tag: 'Biometric',
      );
      return authenticated
          ? BiometricAuthResult.success
          : BiometricAuthResult.cancelled;
    } on PlatformException catch (e) {
      AppLogger.warning(
        '[Biometric] Authentication exception: ${e.code} - ${e.message}',
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
    } catch (e) {
      AppLogger.error('[Biometric] Unexpected auth failure: $e', tag: 'Biometric');
      return BiometricAuthResult.failure;
    }
  }

  Future<void> stopAuthentication() async {
    if (kIsWeb) return;
    try {
      await _auth.stopAuthentication();
    } on PlatformException catch (e) {
      AppLogger.warning('stopAuthentication failed', tag: 'Biometric', error: e);
    }
  }
}
