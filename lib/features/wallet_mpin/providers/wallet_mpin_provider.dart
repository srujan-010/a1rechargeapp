import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/wallet_mpin_repository.dart';

final walletMpinProvider = StateNotifierProvider<WalletMpinNotifier, WalletMpinState>((ref) {
  return WalletMpinNotifier(ref.read(walletMpinRepositoryProvider));
});

class WalletMpinState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final String? resetToken;

  // Status
  final bool? walletMpinConfigured;
  final bool? isLocked;
  final DateTime? lockUntil;
  final int? failedAttempts;

  WalletMpinState({
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.resetToken,
    this.walletMpinConfigured,
    this.isLocked,
    this.lockUntil,
    this.failedAttempts,
  });

  WalletMpinState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    String? resetToken,
    bool? walletMpinConfigured,
    bool? isLocked,
    DateTime? lockUntil,
    int? failedAttempts,
  }) {
    return WalletMpinState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // always allow clearing error
      successMessage: successMessage, // always allow clearing success
      resetToken: resetToken ?? this.resetToken,
      walletMpinConfigured: walletMpinConfigured ?? this.walletMpinConfigured,
      isLocked: isLocked ?? this.isLocked,
      lockUntil: lockUntil ?? this.lockUntil,
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }
}

class WalletMpinNotifier extends StateNotifier<WalletMpinState> {
  final WalletMpinRepository _repository;

  WalletMpinNotifier(this._repository) : super(WalletMpinState()) {
    fetchStatus();
  }

  Future<void> fetchStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final status = await _repository.getStatus();
      state = state.copyWith(
        isLoading: false,
        walletMpinConfigured: status['walletMpinConfigured'] as bool?,
        isLocked: status['isLocked'] as bool?,
        lockUntil: status['lockUntil'] != null ? DateTime.tryParse(status['lockUntil']) : null,
        failedAttempts: status['failedAttempts'] as int?,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createMpin(String mpin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.createMpin(mpin);
      state = state.copyWith(
        isLoading: false, 
        successMessage: 'MPIN created successfully',
        walletMpinConfigured: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> verifyMpin(String mpin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.verifyMpin(mpin);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      // Re-fetch status to update lock status if failed
      fetchStatus();
      return false;
    }
  }

  Future<bool> changeMpin(String currentMpin, String newMpin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.changeMpin(currentMpin, newMpin);
      state = state.copyWith(isLoading: false, successMessage: 'MPIN changed successfully');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> sendForgotOtp() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.sendForgotOtp();
      state = state.copyWith(isLoading: false, successMessage: 'OTP sent');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> verifyForgotOtp({String? otp, String? accessToken}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await _repository.verifyForgotOtp(otp: otp, accessToken: accessToken);
      state = state.copyWith(isLoading: false, resetToken: token);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> resetMpin(String newMpin) async {
    if (state.resetToken == null) {
      state = state.copyWith(error: 'Reset token not found');
      return false;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.resetMpin(state.resetToken!, newMpin);
      state = state.copyWith(
        isLoading: false, 
        successMessage: 'MPIN reset successfully',
        resetToken: null, // clear token
        walletMpinConfigured: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null, successMessage: null);
  }
}
