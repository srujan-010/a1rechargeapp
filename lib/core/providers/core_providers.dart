import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../services/secure_storage_service.dart';

/// 1. Secure Storage Provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// 2. API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(secureStorage: ref.watch(secureStorageProvider));
});

final sessionProvider = FutureProvider<SessionUser?>((ref) async {
  final secureStorage = ref.watch(secureStorageProvider);
  final hasToken = await secureStorage.isTokenValid();
  if (hasToken) {
    try {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get<Map<String, dynamic>>(
        '/auth/me',
        fromJson: (json) => json as Map<String, dynamic>,
      );
      if (response.success && response.data != null) {
        return SessionUser.fromJson(response.data!);
      }
    } catch (e) {
      // If fetching fails (e.g. token expired/invalid), we return null
      return null;
    }
  }
  return null;
});

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

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      retailerId: json['retailerId'] ?? '',
      kycStatus: json['kycStatus'] ?? 'notStarted',
      dob: json['dob'],
      gender: json['gender'],
      avatarUrl: json['avatarUrl'],
      hasMpin: json['hasMpin'] ?? false,
      isVerified: json['isVerified'] ?? false,
      isOnboarded: json['isOnboarded'] ?? false,
      shopName: json['shopName'],
      shopAddress: json['shopAddress'],
      city: json['city'],
      state: json['state'],
      pincode: json['pincode'],
      aadhaarNumber: json['aadhaarNumber'],
      panNumber: json['panNumber'],
      gstNumber: json['gstNumber'],
      createdAt: json['createdAt'],
    );
  }
}
