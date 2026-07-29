sealed class AuthState {
  const AuthState();

  const factory AuthState.initial() = AuthStateInitial;
  const factory AuthState.loading() = AuthStateLoading;
  const factory AuthState.codeSent({
    required String phone,
  }) = AuthStateCodeSent;
  const factory AuthState.authenticated() = AuthStateAuthenticated;
  const factory AuthState.registrationRequired({
    required String phone,
    required String tempSessionToken,
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
  final String phone;
  const AuthStateCodeSent({required this.phone});
}

class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated();
}

class AuthStateRegistrationRequired extends AuthState {
  final String phone;
  final String tempSessionToken;
  const AuthStateRegistrationRequired({
    required this.phone,
    required this.tempSessionToken,
  });
}

class AuthStateError extends AuthState {
  final String message;
  const AuthStateError(this.message);
}
