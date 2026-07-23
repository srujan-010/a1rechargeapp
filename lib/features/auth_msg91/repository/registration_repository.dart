import '../../../core/services/api_client.dart';
import '../../../core/models/app_exception.dart';

class RegistrationRepository {
  final ApiClient _apiClient;

  RegistrationRepository({required ApiClient apiClient}) 
    : _apiClient = apiClient;

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
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/register',
        headers: {
          'Authorization': 'Bearer $tempSessionToken',
        },
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
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred during registration');
    }
  }
}
