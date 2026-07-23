import 'package:flutter/foundation.dart';
import '../../../core/services/api_client.dart';
import '../../../core/models/api_response.dart';

class Msg91ApiService {
  final ApiClient _apiClient;

  Msg91ApiService(this._apiClient);

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/msg91/send-otp',
      data: {'phone': phone},
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/msg91/verify-otp',
      data: {'phone': phone, 'otp': otp},
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> msg91Login(String accessToken) async {
    debugPrint('[MSG91 ApiService] POST /auth/msg91-login');
    debugPrint('[MSG91 ApiService] Body: {"accessToken": "${accessToken.substring(0, accessToken.length > 30 ? 30 : accessToken.length)}..."}');
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/auth/msg91-login',
      data: {'accessToken': accessToken},
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return response.data ?? {};
  }
}
