import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/models/app_exception.dart';

class AuthResponse {
  final bool isNewUser;
  final String? phone;
  final String? firebaseUid;

  AuthResponse({required this.isNewUser, this.phone, this.firebaseUid});
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

class AuthRepository {
  final FirebaseAuth firebaseAuth;
  final ApiClient apiClient;
  final SecureStorageService secureStorage;

  AuthRepository({
    required this.firebaseAuth,
    required this.apiClient,
    required this.secureStorage,
  });

  /// 1. Request OTP via Firebase
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 30),
    );
  }

  /// 2. Verify OTP internally with Firebase and exchange for Backend JWT
  Future<AuthResponse> verifyOtpAndLogin({
    required String verificationId,
    required String smsCode,
  }) async {
    // 1. Create Firebase Credential
    final AuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    // 2. Sign in with Firebase
    final UserCredential userCredential = await firebaseAuth.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user == null) {
      throw Exception('Firebase authentication failed. User is null.');
    }

    // 3. Get Firebase ID Token
    final String? idToken = await user.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to retrieve Firebase ID Token.');
    }

    // 4. Send token to our Node.js backend
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/firebase-login',
      data: {'idToken': idToken},
      fromJson: (json) => json as Map<String, dynamic>,
    );

    // 5. Check if new user or existing user
    if (response.success && response.data != null) {
      final data = response.data!;
      final bool isNewUser = data['isNewUser'] == true;
      
      if (isNewUser) {
        return AuthResponse(
          isNewUser: true,
          phone: data['phone'],
          firebaseUid: data['firebaseUid'],
        );
      } else {
        final String? accessToken = data['accessToken'];
        if (accessToken != null) {
          await secureStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: accessToken,
            expiry: DateTime.now().add(const Duration(days: 30)),
          );
          return AuthResponse(isNewUser: false);
        } else {
          throw const UnknownException(message: 'Backend did not return an access token');
        }
      }
    } else {
      throw ServerException(message: response.message ?? 'Unknown backend error');
    }
  }

  /// Handles auto-verification (Android)
  Future<AuthResponse> loginWithCredential(PhoneAuthCredential credential) async {
    final UserCredential userCredential = await firebaseAuth.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user == null) {
      throw Exception('Firebase auto-verification failed. User is null.');
    }

    final String? idToken = await user.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to retrieve Firebase ID Token.');
    }

    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/firebase-login',
      data: {'idToken': idToken},
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      final bool isNewUser = data['isNewUser'] == true;
      
      if (isNewUser) {
        return AuthResponse(
          isNewUser: true,
          phone: data['phone'],
          firebaseUid: data['firebaseUid'],
        );
      } else {
        final String? accessToken = data['accessToken'];
        if (accessToken != null) {
          await secureStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: accessToken,
            expiry: DateTime.now().add(const Duration(days: 30)),
          );
          return AuthResponse(isNewUser: false);
        } else {
          throw const UnknownException(message: 'Backend did not return an access token');
        }
      }
    } else {
      throw ServerException(message: response.message ?? 'Unknown backend error');
    }
  }

  Future<void> registerRetailer(Map<String, dynamic> data) async {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Firebase authentication required to register.');
    }
    final String? idToken = await user.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to retrieve Firebase ID Token.');
    }

    final payload = {...data, 'idToken': idToken};
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/register',
      data: payload,
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (response.success && response.data != null) {
      final responseData = response.data!;
      final String? accessToken = responseData['accessToken'];
      if (accessToken != null) {
        await secureStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: accessToken,
          expiry: DateTime.now().add(const Duration(days: 30)),
        );
      } else {
        throw const UnknownException(message: 'Backend did not return an access token after registration');
      }
    } else {
      throw ServerException(message: response.message ?? 'Unknown backend error during registration');
    }
  }

  Future<void> logout() async {
    await firebaseAuth.signOut();
    await secureStorage.clearSession();
  }
}
