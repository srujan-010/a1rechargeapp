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
}
