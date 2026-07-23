import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/registration_repository.dart';
import '../../../core/providers/core_providers.dart';

final registrationRepositoryProvider = Provider<RegistrationRepository>((ref) {
  return RegistrationRepository(apiClient: ref.watch(apiClientProvider));
});

class RegistrationState {
  final bool isLoading;
  final String? error;
  final bool isRegistered;

  RegistrationState({
    this.isLoading = false,
    this.error,
    this.isRegistered = false,
  });

  RegistrationState copyWith({
    bool? isLoading,
    String? error,
    bool? isRegistered,
  }) {
    return RegistrationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }
}

class RegistrationNotifier extends StateNotifier<RegistrationState> {
  final RegistrationRepository _repository;
  final Ref _ref;

  RegistrationNotifier(this._repository, this._ref) : super(RegistrationState());

  Future<void> register({
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
    this.state = this.state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.registerRetailer(
        tempSessionToken: tempSessionToken,
        name: name,
        shopName: shopName,
        address: address,
        email: email,
        state: state,
        district: district,
        pincode: pincode,
        referralCode: referralCode,
      );

      if (response['success'] == true) {
        final token = response['token'];
        if (token != null) {
          final secureStorage = _ref.read(secureStorageProvider);
          await secureStorage.saveTokens(
            accessToken: token,
            refreshToken: '',
            expiry: DateTime.now().add(const Duration(days: 30)),
          );
          _ref.invalidate(sessionProvider);
        }
        this.state = this.state.copyWith(isLoading: false, isRegistered: true);
      } else {
        this.state = this.state.copyWith(isLoading: false, error: response['message'] ?? 'Registration failed');
      }
    } catch (e) {
      this.state = this.state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }
}

final registrationProvider = StateNotifierProvider<RegistrationNotifier, RegistrationState>((ref) {
  return RegistrationNotifier(ref.read(registrationRepositoryProvider), ref);
});
