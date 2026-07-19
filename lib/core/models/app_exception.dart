// lib/core/models/app_exception.dart
// Typed exception hierarchy for the A1 Recharge app.
// Every repository must throw only these typed exceptions.
// Never let raw DioException or PlatformException escape to the UI layer.

/// Base class for all A1 Recharge application exceptions.
sealed class AppException implements Exception {
  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  final String message;
  final String? code;
  final Object? originalError;

  @override
  String toString() => message;
}

/// Network connectivity or server reachability failure.
final class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
    this.statusCode,
    this.isTimeout = false,
    this.isNoConnection = false,
    this.isDnsFailure = false,
    this.isServerUnreachable = false,
    this.isServerWakingUp = false,
  });

  final int? statusCode;
  final bool isTimeout;
  final bool isNoConnection;
  final bool isDnsFailure;
  final bool isServerUnreachable;
  final bool isServerWakingUp;

  static const NetworkException noConnection = NetworkException(
    message: 'No internet connection.',
    isNoConnection: true,
  );

  static const NetworkException timeout = NetworkException(
    message: 'Server took too long to respond.',
    isTimeout: true,
  );

  static const NetworkException dnsFailure = NetworkException(
    message: 'Could not find the server. Please check your DNS or internet connection.',
    isDnsFailure: true,
  );

  static const NetworkException serverUnreachable = NetworkException(
    message: 'Unable to reach the server.',
    isServerUnreachable: true,
  );

  static const NetworkException serverWakingUp = NetworkException(
    message: 'Server is currently waking up from sleep. Please try again in a few seconds.',
    isServerWakingUp: true,
  );
}

/// Authentication / authorization failure (401, 403, token expired).
final class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
    this.isSessionExpired = false,
    this.isUnauthorized = false,
  });

  final bool isSessionExpired;
  final bool isUnauthorized;

  static const AuthException sessionExpired = AuthException(
    message: 'Your session has expired. Please log in again.',
    isSessionExpired: true,
  );

  static const AuthException unauthorized = AuthException(
    message: 'You are not authorized to perform this action.',
    isUnauthorized: true,
  );

  static const AuthException invalidOtp = AuthException(
    message: 'Invalid OTP. Please check and try again.',
    code: 'INVALID_OTP',
  );

  static const AuthException invalidMpin = AuthException(
    message: 'Incorrect PIN. Please try again.',
    code: 'INVALID_MPIN',
  );
}

/// Input validation failure (client-side or server-side field validation).
final class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code,
    super.originalError,
    this.fieldErrors = const {},
  });

  final Map<String, String> fieldErrors;
}

/// Server returned a 5xx error or an unexpected response.
final class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.code,
    super.originalError,
    this.statusCode,
  });

  final int? statusCode;

  static const ServerException generic = ServerException(
    message: 'Something went wrong. Please try again.',
    code: 'SERVER_ERROR',
  );
}

/// Transaction or business logic failure (e.g. insufficient balance, operator down).
final class TransactionException extends AppException {
  const TransactionException({
    required super.message,
    super.code,
    super.originalError,
    this.transactionId,
  });

  final String? transactionId;

  static const TransactionException insufficientBalance = TransactionException(
    message: 'Insufficient wallet balance. Please top up your wallet to continue.',
    code: 'INSUFFICIENT_BALANCE',
  );
}

/// Catch-all for truly unexpected exceptions.
final class UnknownException extends AppException {
  const UnknownException({
    required super.message,
    super.code,
    super.originalError,
  });

  factory UnknownException.from(Object error) => UnknownException(
        message: 'An unexpected error occurred. Please try again.',
        originalError: error,
      );
}
