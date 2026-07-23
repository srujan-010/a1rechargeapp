import 'package:flutter/foundation.dart';
import '../../../core/services/api_client.dart';
import '../../../core/models/api_response.dart';

class Msg91ApiService {
  final ApiClient _apiClient;

  Msg91ApiService(this._apiClient);

  Future<dynamic> sendOtp(String phone) async {
    final response = await _apiClient.post<dynamic>('/msg91/send-otp', data: {
      'phone': phone,
    });
    return response.data; // Ensure this matches what repository expects
  }

  Future<dynamic> verifyOtp(String phone, String otp) async {
    final response = await _apiClient.post<dynamic>('/msg91/verify-otp', data: {
      'phone': phone,
      'otp': otp,
    });
    return response.data;
  }

  Future<dynamic> msg91Login(String accessToken) async {
    debugPrint('[MSG91 ApiService] POST /auth/msg91-login');
    debugPrint('[MSG91 ApiService] Body: {"accessToken": "${accessToken.substring(0, accessToken.length > 30 ? 30 : accessToken.length)}..."}');
    final response = await _apiClient.post<dynamic>('/auth/msg91-login', data: {
      'accessToken': accessToken,
    });
    return response.data;
  }
}
