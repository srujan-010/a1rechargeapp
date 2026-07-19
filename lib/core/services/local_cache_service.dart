// lib/core/services/local_cache_service.dart
// Hive wrapper for non-sensitive local caching.
// IMPORTANT: Never store JWT tokens, MPIN, or sensitive financial data here.
// Use SecureStorageService for sensitive data.

import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';

abstract final class _Boxes {
  static const String wallet = 'wallet_cache';
  static const String operators = 'operators_cache';
  static const String offers = 'offers_cache';
  static const String dashboard = 'dashboard_cache';
  static const String userProfile = 'user_profile_cache';
  static const String recentContacts = 'recent_contacts_cache';
  static const String settings = 'settings_cache';
}

class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  /// Must be called during app bootstrap before any cache access.
  static Future<void> initialize() async {
    await Hive.initFlutter();
    // Open all boxes upfront
    await Future.wait([
      Hive.openBox<dynamic>(_Boxes.wallet),
      Hive.openBox<dynamic>(_Boxes.operators),
      Hive.openBox<dynamic>(_Boxes.offers),
      Hive.openBox<dynamic>(_Boxes.dashboard),
      Hive.openBox<dynamic>(_Boxes.userProfile),
      Hive.openBox<dynamic>(_Boxes.recentContacts),
      Hive.openBox<dynamic>(_Boxes.settings),
    ]);
    AppLogger.info('Local cache initialized', tag: 'Cache');
  }

  Box<dynamic> get _walletBox => Hive.box<dynamic>(_Boxes.wallet);
  Box<dynamic> get _operatorsBox => Hive.box<dynamic>(_Boxes.operators);
  Box<dynamic> get _offersBox => Hive.box<dynamic>(_Boxes.offers);
  Box<dynamic> get _dashboardBox => Hive.box<dynamic>(_Boxes.dashboard);
  Box<dynamic> get _profileBox => Hive.box<dynamic>(_Boxes.userProfile);
  Box<dynamic> get _recentContactsBox => Hive.box<dynamic>(_Boxes.recentContacts);
  Box<dynamic> get _settingsBox => Hive.box<dynamic>(_Boxes.settings);

  // ─── Generic Cache Operations ─────────────────────────────────────

  Future<void> put(Box<dynamic> box, String key, dynamic value) async {
    await box.put(key, value);
  }

  T? get<T>(Box<dynamic> box, String key) {
    return box.get(key) as T?;
  }

  Future<void> delete(Box<dynamic> box, String key) async {
    await box.delete(key);
  }

  // ─── Cached Entry With TTL ────────────────────────────────────────

  Future<void> putWithExpiry(
    Box<dynamic> box,
    String key,
    dynamic value, {
    Duration ttl = const Duration(hours: 1),
  }) async {
    final entry = {
      'data': value,
      'expiresAt': DateTime.now().add(ttl).toIso8601String(),
    };
    await box.put(key, entry);
  }

  T? getIfFresh<T>(Box<dynamic> box, String key) {
    final entry = box.get(key) as Map<dynamic, dynamic>?;
    if (entry == null) return null;
    final expiryStr = entry['expiresAt'] as String?;
    if (expiryStr == null) return null;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null || DateTime.now().isAfter(expiry)) {
      box.delete(key);
      return null;
    }
    return entry['data'] as T?;
  }

  // ─── Named Accessors ─────────────────────────────────────────────

  Box<dynamic> get walletBox => _walletBox;
  Box<dynamic> get operatorsBox => _operatorsBox;
  Box<dynamic> get offersBox => _offersBox;
  Box<dynamic> get dashboardBox => _dashboardBox;
  Box<dynamic> get profileBox => _profileBox;
  Box<dynamic> get recentContactsBox => _recentContactsBox;
  Box<dynamic> get settingsBox => _settingsBox;

  // ─── Clear All (on logout) ────────────────────────────────────────
  Future<void> clearAll() async {
    await Future.wait([
      _walletBox.clear(),
      _operatorsBox.clear(),
      _offersBox.clear(),
      _dashboardBox.clear(),
      _profileBox.clear(),
      _recentContactsBox.clear(),
    ]);
    AppLogger.info('All cache cleared on logout', tag: 'Cache');
  }
}
