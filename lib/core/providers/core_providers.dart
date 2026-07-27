import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../services/secure_storage_service.dart';
import '../services/local_cache_service.dart';
import '../utils/logger.dart';

/// 1. Secure Storage Provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// 2. API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(secureStorage: ref.watch(secureStorageProvider));
});

/// 3. Fast Local JWT Validation Provider (Non-network)
final hasValidJwtProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final isTokenValid = await storage.isTokenValid();
  if (isTokenValid) return true;
  final hasRefresh = await storage.hasRefreshToken();
  return hasRefresh;
});

/// Non-Blocking Stale-While-Revalidate User Session Provider
class SessionNotifier extends AsyncNotifier<SessionUser?> {
  @override
  FutureOr<SessionUser?> build() {
    final cache = LocalCacheService.instance;
    final cachedMap = cache.get<Map<dynamic, dynamic>>(cache.profileBox, 'cached_user');
    SessionUser? cachedUser;

    if (cachedMap != null) {
      try {
        cachedUser = SessionUser.fromJson(Map<String, dynamic>.from(cachedMap));
      } catch (e) {
        AppLogger.warning('Failed to parse cached user profile', tag: 'Cache');
      }
    }

    _refreshInBackground();

    return cachedUser;
  }

  Future<void> _refreshInBackground() async {
    final secureStorage = ref.read(secureStorageProvider);
    final hasToken = await secureStorage.isTokenValid();
    if (!hasToken) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get<Map<String, dynamic>>(
        '/auth/me',
        fromJson: (json) => json as Map<String, dynamic>,
      ).timeout(const Duration(seconds: 3));

      if (response.success && response.data != null) {
        final user = SessionUser.fromJson(response.data!);
        LocalCacheService.instance.put(
          LocalCacheService.instance.profileBox,
          'cached_user',
          user.toJson(),
        );
        state = AsyncData(user);
      }
    } catch (e) {
      AppLogger.warning('Profile fetch background revalidation error: $e', tag: 'SessionNotifier');
    }
  }

  Future<void> saveUser(SessionUser user) async {
    LocalCacheService.instance.put(
      LocalCacheService.instance.profileBox,
      'cached_user',
      user.toJson(),
    );
    state = AsyncData(user);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, SessionUser?>(
  SessionNotifier.new,
);

class SessionUser {
  final String id;
  final String phone;
  final String name;
  final String? email;
  final String retailerId;
  final String kycStatus;
  final String? dob;
  final String? gender;
  final String? avatarUrl;
  final bool hasMpin;
  final bool isVerified;
  final bool isOnboarded;
  
  // Shop details
  final String? shopName;
  final String? shopAddress;
  final String? city;
  final String? state;
  final String? pincode;

  // Identity
  final String? aadhaarNumber;
  final String? panNumber;
  final String? gstNumber;

  // Timestamps
  final String? createdAt;

  SessionUser({
    required this.id,
    required this.phone,
    required this.name,
    this.email,
    required this.retailerId,
    required this.kycStatus,
    this.dob,
    this.gender,
    this.avatarUrl,
    required this.hasMpin,
    required this.isVerified,
    required this.isOnboarded,
    this.shopName,
    this.shopAddress,
    this.city,
    this.state,
    this.pincode,
    this.aadhaarNumber,
    this.panNumber,
    this.gstNumber,
    this.createdAt,
  });

  factory SessionUser.fromJson(Map<String, dynamic> rawJson) {
    Map<String, dynamic> json = Map<String, dynamic>.from(rawJson);

    // Automatically unwrap nested 'data' or 'user' maps if present
    if (json.containsKey('data') && json['data'] is Map) {
      json = Map<String, dynamic>.from(json['data'] as Map);
    }
    if (json.containsKey('user') && json['user'] is Map) {
      json = Map<String, dynamic>.from(json['user'] as Map);
    }

    final String extractedId = (json['id'] ?? json['_id'] ?? json['userId'] ?? '').toString();
    final String extractedPhone = (json['phone'] ?? json['mobile'] ?? json['mobileNo'] ?? json['phoneNumber'] ?? '').toString();
    final String extractedName = (json['name'] ?? json['fullName'] ?? json['retailerName'] ?? json['username'] ?? '').toString();
    final String? extractedEmail = json['email']?.toString() ?? json['emailId']?.toString();
    final String extractedRetailerId = (json['retailerId'] ?? json['retailer_id'] ?? json['merchantId'] ?? json['merchant_id'] ?? '').toString();
    final String extractedKycStatus = (json['kycStatus'] ?? json['kyc_status'] ?? (json['kyc'] is Map ? json['kyc']['status'] : null) ?? 'notStarted').toString();
    final String? extractedAvatar = json['avatarUrl']?.toString() ?? json['profilePhoto']?.toString() ?? json['photoUrl']?.toString() ?? json['avatar']?.toString();
    final String? extractedShopName = json['shopName']?.toString() ?? json['shop_name']?.toString() ?? json['businessName']?.toString();
    final String? extractedCreatedAt = json['createdAt']?.toString() ?? json['joinedDate']?.toString() ?? json['created_at']?.toString();

    final user = SessionUser(
      id: extractedId,
      phone: extractedPhone,
      name: extractedName,
      email: extractedEmail,
      retailerId: extractedRetailerId,
      kycStatus: extractedKycStatus,
      dob: json['dob']?.toString(),
      gender: json['gender']?.toString(),
      avatarUrl: extractedAvatar,
      hasMpin: json['hasMpin'] == true || json['has_mpin'] == true,
      isVerified: json['isVerified'] == true || json['is_verified'] == true,
      isOnboarded: json['isOnboarded'] == true || json['is_onboarded'] == true,
      shopName: extractedShopName,
      shopAddress: json['shopAddress']?.toString() ?? json['address']?.toString(),
      city: json['city']?.toString() ?? json['district']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
      aadhaarNumber: json['aadhaarNumber']?.toString(),
      panNumber: json['panNumber']?.toString(),
      gstNumber: json['gstNumber']?.toString(),
      createdAt: extractedCreatedAt,
    );

    // Task 8 Debug Logs
    print('\n========== USER MODEL ==========');
    print('API Response Raw: $rawJson');
    print('Mapped User Model: id=${user.id}, name="${user.name}", phone="${user.phone}", retailerId="${user.retailerId}", kyc="${user.kycStatus}"');
    print('================================\n');

    return user;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'email': email,
    'retailerId': retailerId,
    'kycStatus': kycStatus,
    'dob': dob,
    'gender': gender,
    'avatarUrl': avatarUrl,
    'hasMpin': hasMpin,
    'isVerified': isVerified,
    'isOnboarded': isOnboarded,
    'shopName': shopName,
    'shopAddress': shopAddress,
    'city': city,
    'state': state,
    'pincode': pincode,
    'aadhaarNumber': aadhaarNumber,
    'panNumber': panNumber,
    'gstNumber': gstNumber,
    'createdAt': createdAt,
  };
}

