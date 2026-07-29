import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/models/app_exception.dart';

class AuthResponse {
  final bool isNewUser;
  final String? phone;
  final String? tempSessionToken;
  final SessionUser? user;

  AuthResponse({
    required this.isNewUser,
    this.phone,
    this.tempSessionToken,
    this.user,
  });
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

class AuthRepository {
  final ApiClient apiClient;
  final SecureStorageService secureStorage;

  AuthRepository({
    required this.apiClient,
    required this.secureStorage,
  });

  /// 1. Send OTP via Fast2SMS WhatsApp API
  Future<void> sendOtp(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/send-otp',
      data: {'mobile': cleanPhone},
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (!response.success) {
      throw ServerException(message: response.message ?? 'Failed to send OTP via WhatsApp.');
    }
  }

  /// 2. Verify OTP sent via Fast2SMS WhatsApp API
  Future<AuthResponse> verifyOtpAndLogin({
    required String phone,
    required String smsCode,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      data: {
        'mobile': cleanPhone,
        'otp': smsCode,
      },
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      final bool isNewUser = data['isNewUser'] == true;

      if (isNewUser) {
        return AuthResponse(
          isNewUser: true,
          phone: data['mobile'] ?? cleanPhone,
          tempSessionToken: data['tempSessionToken'],
        );
      } else {
        final String? accessToken = data['accessToken'] ?? data['token'];
        if (accessToken != null) {
          await secureStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: accessToken,
            expiry: DateTime.now().add(const Duration(days: 30)),
          );

          SessionUser? user;
          if (data['user'] != null && data['user'] is Map) {
            try {
              user = SessionUser.fromJson(data['user'] as Map<String, dynamic>);
            } catch (_) {}
          }

          return AuthResponse(isNewUser: false, user: user);
        } else {
          throw const UnknownException(message: 'Backend did not return an access token');
        }
      }
    } else {
      throw ServerException(message: response.message ?? 'Invalid OTP code');
    }
  }

  /// 3. Resend OTP via Fast2SMS WhatsApp API
  Future<void> resendOtp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/resend-otp',
      data: {'mobile': cleanPhone},
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (!response.success) {
      throw ServerException(message: response.message ?? 'Failed to resend OTP.');
    }
  }

  /// 4. Register Retailer after OTP verification using tempSessionToken
  Future<void> registerRetailer({
    required String tempSessionToken,
    required String name,
    required String shopName,
    required String address,
    String? email,
    String? state,
    String? district,
    String? pincode,
    String? referralCode,
  }) async {
    final payload = {
      'name': name,
      'shopName': shopName,
      'address': address,
      if (email != null && email.isNotEmpty) 'email': email,
      if (state != null && state.isNotEmpty) 'state': state,
      if (district != null && district.isNotEmpty) 'district': district,
      if (pincode != null && pincode.isNotEmpty) 'pincode': pincode,
      if (referralCode != null && referralCode.isNotEmpty) 'referralCode': referralCode,
    };

    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/register',
      data: payload,
      headers: {'Authorization': 'Bearer $tempSessionToken'},
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (response.success && response.data != null) {
      final responseData = response.data!;
      final String? accessToken = responseData['token'] ?? responseData['accessToken'];
      if (accessToken != null) {
        await secureStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: accessToken,
          expiry: DateTime.now().add(const Duration(days: 30)),
        );
      } else {
        throw const UnknownException(message: 'Backend did not return an access token after registration');
      }
    } else {
      throw ServerException(message: response.message ?? 'Registration failed.');
    }
  }

  Future<void> logout() async {
    await secureStorage.clearSession();
  }
}
