import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallet_mpin_api_service.dart';
import '../../../core/models/app_exception.dart';

final walletMpinRepositoryProvider = Provider<WalletMpinRepository>((ref) {
  return WalletMpinRepository(ref.read(walletMpinApiServiceProvider));
});

class WalletMpinRepository {
  final WalletMpinApiService _apiService;

  WalletMpinRepository(this._apiService);

  Future<void> createMpin(String mpin) async {
    try {
      await _apiService.createMpin(mpin);
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<void> verifyMpin(String mpin) async {
    try {
      await _apiService.verifyMpin(mpin);
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<void> changeMpin(String currentMpin, String newMpin) async {
    try {
      await _apiService.changeMpin(currentMpin, newMpin);
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<void> sendForgotOtp() async {
    try {
      await _apiService.sendForgotOtp();
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<String> verifyForgotOtp({String? otp, String? accessToken}) async {
    try {
      final res = await _apiService.verifyForgotOtp(otp: otp, accessToken: accessToken);
      if (res['resetToken'] != null) {
        return res['resetToken'] as String;
      }
      throw Exception('Failed to get reset token');
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<void> resetMpin(String resetToken, String newMpin) async {
    try {
      await _apiService.resetMpin(resetToken, newMpin);
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      return await _apiService.getStatus();
    } on AppException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
