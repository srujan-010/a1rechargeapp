import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';

class Msg91ApiService {
  final Dio _dio;

  Msg91ApiService({Dio? dio}) 
    : _dio = dio ?? Dio(BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
      ));

  Future<Response> sendOtp(String phone) async {
    return await _dio.post('/msg91/send-otp', data: {
      'phone': phone,
    });
  }

  Future<Response> verifyOtp(String phone, String otp) async {
    return await _dio.post('/msg91/verify-otp', data: {
      'phone': phone,
      'otp': otp,
    });
  }
}
