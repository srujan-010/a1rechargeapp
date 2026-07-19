import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/logger.dart';

enum ChangeMpinState { idle, sendingOtp, otpSent, verifyingOtp, otpVerified, updatingMpin, success, error }

class ChangeMpinStateModel {
  final ChangeMpinState status;
  final String? errorMsg;
  final String? verificationId;
  final String? idToken;

  ChangeMpinStateModel({
    this.status = ChangeMpinState.idle,
    this.errorMsg,
    this.verificationId,
    this.idToken,
  });

  ChangeMpinStateModel copyWith({
    ChangeMpinState? status,
    String? errorMsg,
    String? verificationId,
    String? idToken,
  }) {
    return ChangeMpinStateModel(
      status: status ?? this.status,
      errorMsg: errorMsg,
      verificationId: verificationId ?? this.verificationId,
      idToken: idToken ?? this.idToken,
    );
  }
}

class ChangeMpinNotifier extends StateNotifier<ChangeMpinStateModel> {
  final Ref ref;

  ChangeMpinNotifier(this.ref) : super(ChangeMpinStateModel());

  Future<void> sendOtp(String rawPhoneNumber) async {
    state = state.copyWith(status: ChangeMpinState.sendingOtp);
    
    // 1. Formatting
    String formattedPhone = rawPhoneNumber.trim();
    if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.length == 10) {
        formattedPhone = '+91$formattedPhone';
      } else if (formattedPhone.startsWith('91') && formattedPhone.length == 12) {
        formattedPhone = '+$formattedPhone';
      } else {
        formattedPhone = '+$formattedPhone'; // fallback
      }
    }
    
    // 2. Validation
    bool isValid = true;
    if (!formattedPhone.startsWith('+')) {
      isValid = false;
    } else {
      final digitsOnly = formattedPhone.substring(1);
      final hasOnlyDigits = RegExp(r'^\d+$').hasMatch(digitsOnly);
      if (!hasOnlyDigits) {
         isValid = false;
      }
      if (formattedPhone.startsWith('+91') && formattedPhone.length != 13) {
         isValid = false;
      }
    }

    // 3. Debug Logs
    final displayedPhone = rawPhoneNumber.length >= 10 
        ? '+91 XXXXXXX${rawPhoneNumber.substring(rawPhoneNumber.length - 3)}' 
        : rawPhoneNumber;
    
    AppLogger.info('--- Firebase Phone Auth Debug ---', tag: 'Mpin');
    AppLogger.info('Displayed phone number: $displayedPhone', tag: 'Mpin');
    AppLogger.info('Actual phone number sent to Firebase: $formattedPhone', tag: 'Mpin');
    AppLogger.info('Validation Result: $isValid', tag: 'Mpin');
    AppLogger.info('---------------------------------', tag: 'Mpin');

    if (!isValid) {
      state = state.copyWith(
        status: ChangeMpinState.error, 
        errorMsg: 'Invalid phone number format for OTP. Expected E.164 (e.g. +919876543210).'
      );
      return;
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (Android only)
          try {
            state = state.copyWith(status: ChangeMpinState.verifyingOtp);
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            final token = await userCredential.user?.getIdToken();
            if (token != null) {
              state = state.copyWith(status: ChangeMpinState.otpVerified, idToken: token);
            } else {
              state = state.copyWith(status: ChangeMpinState.error, errorMsg: 'Failed to retrieve secure token');
            }
          } catch (e) {
            state = state.copyWith(status: ChangeMpinState.error, errorMsg: e.toString());
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          state = state.copyWith(status: ChangeMpinState.error, errorMsg: e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          state = state.copyWith(status: ChangeMpinState.otpSent, verificationId: verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (state.status == ChangeMpinState.sendingOtp) {
            state = state.copyWith(status: ChangeMpinState.otpSent, verificationId: verificationId);
          }
        },
      );
    } catch (e) {
      state = state.copyWith(status: ChangeMpinState.error, errorMsg: e.toString());
    }
  }

  Future<void> verifyOtp(String smsCode) async {
    if (state.verificationId == null) return;
    state = state.copyWith(status: ChangeMpinState.verifyingOtp);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final token = await userCredential.user?.getIdToken(true); // force refresh
      if (token != null) {
        state = state.copyWith(status: ChangeMpinState.otpVerified, idToken: token);
      } else {
        state = state.copyWith(status: ChangeMpinState.error, errorMsg: 'Failed to retrieve secure token');
      }
    } catch (e) {
      state = state.copyWith(status: ChangeMpinState.error, errorMsg: e.toString());
    }
  }

  Future<void> updateMpin(String newMpin) async {
    if (state.idToken == null) {
      state = state.copyWith(status: ChangeMpinState.error, errorMsg: 'Not authenticated for this action');
      return;
    }
    state = state.copyWith(status: ChangeMpinState.updatingMpin);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/auth/change-mpin',
        data: {
          'idToken': state.idToken,
          'newMpin': newMpin,
        },
        fromJson: (json) => json,
      );

      if (response.success) {
        state = state.copyWith(status: ChangeMpinState.success);
      } else {
        state = state.copyWith(status: ChangeMpinState.error, errorMsg: response.message ?? 'Failed to update MPIN');
      }
    } catch (e) {
      state = state.copyWith(status: ChangeMpinState.error, errorMsg: e.toString());
    }
  }

  void reset() {
    state = ChangeMpinStateModel();
  }
}

final changeMpinProvider = StateNotifierProvider<ChangeMpinNotifier, ChangeMpinStateModel>((ref) {
  return ChangeMpinNotifier(ref);
});
