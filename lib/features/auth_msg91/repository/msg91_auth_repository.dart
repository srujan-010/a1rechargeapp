import 'package:flutter/foundation.dart';
import '../services/msg91_api_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/models/app_exception.dart';

class Msg91AuthRepository {
  final Msg91ApiService _apiService;

  Msg91AuthRepository({required ApiClient apiClient})
      : _apiService = Msg91ApiService(apiClient);

  Future<void> sendOtp(String phone) async {
    try {
      await _apiService.sendOtp(phone);
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    try {
      final response = await _apiService.verifyOtp(phone, otp);
      return response as Map<String, dynamic>;
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<Map<String, dynamic>> loginWithAccessToken(String accessToken) async {
    debugPrint('[MSG91 Repository] loginWithAccessToken() called. Token length=${accessToken.length}');
    try {
      debugPrint('[MSG91 Repository] Calling _apiService.msg91Login()');
      final response = await _apiService.msg91Login(accessToken);
      return response as Map<String, dynamic>;
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
