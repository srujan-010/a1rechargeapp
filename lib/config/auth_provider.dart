enum AuthProviderType {
  firebase,
  msg91,
}

class AppAuthConfig {
  // Set to msg91 to use MSG91 API for authentication
  // Change this flag to switch between Firebase Phone Auth and MSG91 OTP
  static const AuthProviderType provider = AuthProviderType.firebase;
}
