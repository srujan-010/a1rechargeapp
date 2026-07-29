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
  static const String history = 'history_cache';
  static const String plans = 'plans_cache';
  static const String notifications = 'notifications_cache';
  static const String ledger = 'ledger_cache';
  static const String commission = 'commission_cache';
}

class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();
  static bool _isInitialized = false;

  /// Must be called during app bootstrap before any cache access.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    AppLogger.info('Hive Initialization Started', tag: 'Cache');

    try {
      await Hive.initFlutter();
      AppLogger.info('Hive Adapter Registered / Flutter Init Complete', tag: 'Cache');
    } catch (e) {
      AppLogger.warning('Hive.initFlutter already initialized or skipped: $e', tag: 'Cache');
    }

    final boxesToOpen = [
      _Boxes.wallet,
      _Boxes.operators,
      _Boxes.offers,
      _Boxes.dashboard,
      _Boxes.userProfile,
      _Boxes.recentContacts,
      _Boxes.settings,
      _Boxes.history,
      _Boxes.plans,
      _Boxes.notifications,
      _Boxes.ledger,
      _Boxes.commission,
    ];

    for (final boxName in boxesToOpen) {
      try {
        if (!Hive.isBoxOpen(boxName)) {
          await Hive.openBox<dynamic>(boxName);
          AppLogger.info('Hive Box Opened Successfully: $boxName', tag: 'Cache');
        } else {
          AppLogger.info('Hive Box Already Open: $boxName', tag: 'Cache');
        }
      } catch (e) {
        AppLogger.error('Failed to open Hive Box: $boxName', tag: 'Cache', error: e);
      }
    }

    _isInitialized = true;
    AppLogger.info('Hive Initialization Complete — All 12 boxes ready', tag: 'Cache');
  }

  /// Safe accessor that opens the box asynchronously if not yet opened
  Box<dynamic> _getSafeBox(String boxName) {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<dynamic>(boxName);
    }

    AppLogger.warning('Hive Box Not Open: "$boxName". Auto-opening box...', tag: 'Cache');
    Hive.openBox<dynamic>(boxName);
    return Hive.box<dynamic>(boxName);
  }

  Box<dynamic> get walletBox => _getSafeBox(_Boxes.wallet);
  Box<dynamic> get operatorsBox => _getSafeBox(_Boxes.operators);
  Box<dynamic> get offersBox => _getSafeBox(_Boxes.offers);
  Box<dynamic> get dashboardBox => _getSafeBox(_Boxes.dashboard);
  Box<dynamic> get profileBox => _getSafeBox(_Boxes.userProfile);
  Box<dynamic> get recentContactsBox => _getSafeBox(_Boxes.recentContacts);
  Box<dynamic> get settingsBox => _getSafeBox(_Boxes.settings);
  Box<dynamic> get historyBox => _getSafeBox(_Boxes.history);
  Box<dynamic> get plansBox => _getSafeBox(_Boxes.plans);
  Box<dynamic> get notificationsBox => _getSafeBox(_Boxes.notifications);
  Box<dynamic> get ledgerBox => _getSafeBox(_Boxes.ledger);
  Box<dynamic> get commissionBox => _getSafeBox(_Boxes.commission);

  // ─── Generic Cache Operations ─────────────────────────────────────

  Future<void> put(Box<dynamic> box, String key, dynamic value) async {
    try {
      await box.put(key, value);
    } catch (e) {
      AppLogger.error('Hive put error for key $key', tag: 'Cache', error: e);
    }
  }

  T? get<T>(Box<dynamic> box, String key) {
    try {
      return box.get(key) as T?;
    } catch (e) {
      AppLogger.error('Hive get error for key $key', tag: 'Cache', error: e);
      return null;
    }
  }

  Future<void> delete(Box<dynamic> box, String key) async {
    try {
      await box.delete(key);
    } catch (e) {
      AppLogger.error('Hive delete error for key $key', tag: 'Cache', error: e);
    }
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
    try {
      await box.put(key, entry);
    } catch (e) {
      AppLogger.error('Hive putWithExpiry error for key $key', tag: 'Cache', error: e);
    }
  }

  T? getIfFresh<T>(Box<dynamic> box, String key) {
    try {
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
    } catch (e) {
      AppLogger.error('Hive getIfFresh error for key $key', tag: 'Cache', error: e);
      return null;
    }
  }

  // ─── Clear All (on logout) ────────────────────────────────────────
  Future<void> clearAll() async {
    try {
      await Future.wait([
        if (Hive.isBoxOpen(_Boxes.wallet)) _getSafeBox(_Boxes.wallet).clear(),
        if (Hive.isBoxOpen(_Boxes.operators)) _getSafeBox(_Boxes.operators).clear(),
        if (Hive.isBoxOpen(_Boxes.offers)) _getSafeBox(_Boxes.offers).clear(),
        if (Hive.isBoxOpen(_Boxes.dashboard)) _getSafeBox(_Boxes.dashboard).clear(),
        if (Hive.isBoxOpen(_Boxes.userProfile)) _getSafeBox(_Boxes.userProfile).clear(),
        if (Hive.isBoxOpen(_Boxes.recentContacts)) _getSafeBox(_Boxes.recentContacts).clear(),
        if (Hive.isBoxOpen(_Boxes.history)) _getSafeBox(_Boxes.history).clear(),
        if (Hive.isBoxOpen(_Boxes.plans)) _getSafeBox(_Boxes.plans).clear(),
        if (Hive.isBoxOpen(_Boxes.notifications)) _getSafeBox(_Boxes.notifications).clear(),
        if (Hive.isBoxOpen(_Boxes.ledger)) _getSafeBox(_Boxes.ledger).clear(),
        if (Hive.isBoxOpen(_Boxes.commission)) _getSafeBox(_Boxes.commission).clear(),
      ]);
      AppLogger.info('All cache cleared on logout', tag: 'Cache');
    } catch (e) {
      AppLogger.error('Error clearing cache on logout', tag: 'Cache', error: e);
    }
  }
}
