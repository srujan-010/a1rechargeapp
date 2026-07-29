enum AuthProviderType {
  fast2sms,
  firebase,
}

class AppAuthConfig {
  // Authentication Provider for A1 Recharge (Fast2SMS WhatsApp API)
  static const AuthProviderType provider = AuthProviderType.fast2sms;
}
