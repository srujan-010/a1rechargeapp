import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';

class RegistrationRepository {
  final Dio _dio;

  RegistrationRepository({Dio? dio}) 
    : _dio = dio ?? Dio(BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
      ));

  Future<Map<String, dynamic>> registerRetailer({
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
    try {
      final response = await _dio.post(
        '/auth/register',
        options: Options(
          headers: {
            'Authorization': 'Bearer $tempSessionToken',
          },
        ),
        data: {
          'name': name,
          'shopName': shopName,
          'address': address,
          if (email != null && email.isNotEmpty) 'email': email,
          if (state != null && state.isNotEmpty) 'state': state,
          if (district != null && district.isNotEmpty) 'district': district,
          if (pincode != null && pincode.isNotEmpty) 'pincode': pincode,
          if (referralCode != null && referralCode.isNotEmpty) 'referralCode': referralCode,
        },
      );
      return response.data;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Registration failed';
      throw Exception(message);
    } catch (e) {
      throw Exception('An unexpected error occurred during registration');
    }
  }
}
