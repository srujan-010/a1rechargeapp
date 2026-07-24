import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import '../utils/logger.dart';

abstract final class _Keys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String tokenExpiry = 'token_expiry';
  static const String mpinHash = 'mpin_hash';
  static const String biometricEnabled = 'biometric_enabled';
  static const String retailerId = 'retailer_id';
  static const String fcmToken = 'fcm_token';
}

class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _storage;
  
  // Memory cache to prevent Web Crypto OperationError on rapid reads
  String? _cachedAccessToken;

  Box<String>? _webBox;

  Future<Box<String>> _getWebBox() async {
    if (_webBox != null) return _webBox!;
    _webBox = await Hive.openBox<String>('secure_storage_fallback');
    return _webBox!;
  }

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final box = await _getWebBox();
      await box.put(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final box = await _getWebBox();
      return box.get(key);
    } else {
      return _storage.read(key: key);
    }
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      final box = await _getWebBox();
      await box.delete(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  Future<void> _deleteAll() async {
    if (kIsWeb) {
      final box = await _getWebBox();
      await box.clear();
    } else {
      await _storage.deleteAll();
    }
  }

  // ─── Token Management ─────────────────────────────────────────────
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiry,
  }) async {
    _cachedAccessToken = accessToken;
    await Future.wait([
      _write(_Keys.accessToken, accessToken),
      _write(_Keys.refreshToken, refreshToken),
      _write(_Keys.tokenExpiry, expiry.toIso8601String()),
    ]);
    AppLogger.info('Tokens saved to secure storage');
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;
    _cachedAccessToken = await _read(_Keys.accessToken);
    return _cachedAccessToken;
  }

  Future<String?> getRefreshToken() async {
    return _read(_Keys.refreshToken);
  }

  Future<DateTime?> getTokenExpiry() async {
    final raw = await _read(_Keys.tokenExpiry);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> isTokenValid() async {
    final token = await getAccessToken();
    final expiry = await getTokenExpiry();
    if (token == null || expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// Returns true if a refresh token exists in secure storage.
  /// Use this to decide whether a silent token refresh is worth attempting —
  /// even if the access token has expired, a valid refresh token means the
  /// session can be silently renewed without bouncing the user to OTP login.
  Future<bool> hasRefreshToken() async {
    final token = await getRefreshToken();
    return token != null && token.isNotEmpty;
  }

  // ─── MPIN Storage ─────────────────────────────────────────────────
  // SECURITY: Store only the hash, never the plaintext PIN.
  // The actual hashing is done on the backend during setup.
  // Locally we store a derived verification token from the backend.
  Future<void> saveMpinHash(String mpinHash) async {
    await _write(_Keys.mpinHash, mpinHash);
    AppLogger.info('MPIN hash saved to secure storage');
  }

  Future<String?> getMpinHash() async {
    return _read(_Keys.mpinHash);
  }

  Future<bool> hasMpin() async {
    final hash = await getMpinHash();
    return hash != null && hash.isNotEmpty;
  }

  // ─── Biometric ────────────────────────────────────────────────────
  Future<void> setBiometricEnabled({required bool enabled}) async {
    await _write(
      _Keys.biometricEnabled,
      enabled.toString(),
    );
  }

  Future<bool> isBiometricEnabled() async {
    final raw = await _read(_Keys.biometricEnabled);
    return raw == 'true';
  }

  // ─── Retailer ID (for quick access without full profile load) ─────
  Future<void> saveRetailerId(String id) async {
    await _write(_Keys.retailerId, id);
  }

  Future<String?> getRetailerId() async {
    return _read(_Keys.retailerId);
  }

  // ─── FCM Token ────────────────────────────────────────────────────
  Future<void> saveFcmToken(String token) async {
    await _write(_Keys.fcmToken, token);
  }

  Future<String?> getFcmToken() async {
    return _read(_Keys.fcmToken);
  }

  // ─── Full Clear (logout) ─────────────────────────────────────────
  Future<void> clearSession() async {
    _cachedAccessToken = null;
    await Future.wait([
      _delete(_Keys.accessToken),
      _delete(_Keys.refreshToken),
      _delete(_Keys.tokenExpiry),
      _delete(_Keys.retailerId),
      // MPIN hash and biometric preference are intentionally preserved across logout
      // so the user doesn't need to re-setup on next login
    ]);
    AppLogger.info('Session cleared from secure storage');
  }

  Future<void> clearAll() async {
    await _deleteAll();
    AppLogger.info('All secure storage data cleared');
  }
}
