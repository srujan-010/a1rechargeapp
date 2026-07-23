import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/msg91_api_service.dart';

class Msg91AuthRepository {
  final Msg91ApiService _apiService;

  Msg91AuthRepository({Msg91ApiService? apiService})
      : _apiService = apiService ?? Msg91ApiService();

  Future<void> sendOtp(String phone) async {
    try {
      await _apiService.sendOtp(phone);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Failed to send OTP';
      throw Exception(message);
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    try {
      final response = await _apiService.verifyOtp(phone, otp);
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Invalid OTP';
      throw Exception(message);
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<Map<String, dynamic>> loginWithAccessToken(String accessToken) async {
    debugPrint('[MSG91 Repository] loginWithAccessToken() called. Token length=${accessToken.length}');
    try {
      debugPrint('[MSG91 Repository] Calling _apiService.msg91Login()');
      final response = await _apiService.msg91Login(accessToken);
      debugPrint('[MSG91 Repository] HTTP ${response.statusCode} received. Data: ${response.data}');
      return response.data;
    } on DioException catch (e, stackTrace) {
      debugPrint('════════════════════════════════════════');
      debugPrint('[MSG91 Repository] ❌ DioException caught');
      debugPrint('  type        : ${e.type}');
      debugPrint('  message     : ${e.message}');
      debugPrint('  error       : ${e.error}');
      debugPrint('  status code : ${e.response?.statusCode}');
      debugPrint('  status msg  : ${e.response?.statusMessage}');
      debugPrint('  response    : ${e.response?.data}');
      debugPrint('  stack trace : $stackTrace');
      debugPrint('════════════════════════════════════════');
      // Expose the REAL error — never hide it
      final httpMessage = e.response?.data?['message'];
      if (httpMessage != null) {
        throw Exception('HTTP ${e.response?.statusCode}: $httpMessage');
      }
      // No HTTP response — network-level error (SocketException, timeout, etc.)
      throw Exception('[${e.type.name}] ${e.message ?? e.error?.toString() ?? "Network error — no response received"}');
    } catch (e, stackTrace) {
      debugPrint('════════════════════════════════════════');
      debugPrint('[MSG91 Repository] ❌ Unexpected exception caught');
      debugPrint('  runtimeType : ${e.runtimeType}');
      debugPrint('  toString    : $e');
      debugPrint('  stack trace : $stackTrace');
      debugPrint('════════════════════════════════════════');
      rethrow;
    }
  }
}
