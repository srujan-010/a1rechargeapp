import 'package:flutter/foundation.dart';
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

  Future<Response> msg91Login(String accessToken) async {
    debugPrint('[MSG91 ApiService] POST ${_dio.options.baseUrl}/auth/msg91-login');
    debugPrint('[MSG91 ApiService] Body: {"accessToken": "${accessToken.substring(0, accessToken.length > 30 ? 30 : accessToken.length)}..."}');
    return await _dio.post('/auth/msg91-login', data: {
      'accessToken': accessToken,
    });
  }
}
