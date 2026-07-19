import 'user_profile.dart';

sealed class AuthState {
  const AuthState();

  const factory AuthState.initial() = AuthStateInitial;
  const factory AuthState.loading() = AuthStateLoading;
  const factory AuthState.codeSent({
    required String verificationId,
    int? resendToken,
  }) = AuthStateCodeSent;
  const factory AuthState.authenticated() = AuthStateAuthenticated;
  const factory AuthState.registrationRequired({
    required String phone,
    required String firebaseUid,
  }) = AuthStateRegistrationRequired;
  const factory AuthState.error(String message) = AuthStateError;
}

class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}

class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

class AuthStateCodeSent extends AuthState {
  final String verificationId;
  final int? resendToken;
  const AuthStateCodeSent({required this.verificationId, this.resendToken});
}

class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated();
}

class AuthStateRegistrationRequired extends AuthState {
  final String phone;
  final String firebaseUid;
  const AuthStateRegistrationRequired({required this.phone, required this.firebaseUid});
}

class AuthStateError extends AuthState {
  final String message;
  const AuthStateError(this.message);
}
