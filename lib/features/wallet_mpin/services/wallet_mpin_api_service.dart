import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/providers/core_providers.dart';

final walletMpinApiServiceProvider = Provider<WalletMpinApiService>((ref) {
  return WalletMpinApiService(ref.read(apiClientProvider));
});

class WalletMpinApiService {
  final ApiClient _apiClient;

  WalletMpinApiService(this._apiClient);

  Future<Map<String, dynamic>> createMpin(String mpin) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/wallet-mpin/create',
      data: {'mpin': mpin},
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> verifyMpin(String mpin) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/wallet-mpin/verify',
      data: {'mpin': mpin},
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> changeMpin(String currentMpin, String newMpin) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/wallet-mpin/change',
      data: {'currentMpin': currentMpin, 'newMpin': newMpin},
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> sendForgotOtp() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/wallet-mpin/forgot/send-otp',
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> verifyForgotOtp({String? otp, String? accessToken}) async {
    final data = <String, dynamic>{};
    if (otp != null) data['otp'] = otp;
    if (accessToken != null) data['accessToken'] = accessToken;
    
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/wallet-mpin/forgot/verify-otp',
      data: data,
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> resetMpin(String resetToken, String newMpin) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/wallet-mpin/reset',
      data: {'resetToken': resetToken, 'newMpin': newMpin},
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> getStatus() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/wallet-mpin/status',
      fromJson: (json) => json as Map<String, dynamic>,
    );
    return response.data ?? {};
  }
}
