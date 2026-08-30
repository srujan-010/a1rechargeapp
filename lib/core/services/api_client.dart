// lib/core/services/api_client.dart
// Central Dio HTTP client for A1 Recharge.
// All network calls go through this client — never use raw http or create Dio instances elsewhere.
//
// Features:
// - Auth interceptor (Bearer token injection)
// - Silent 401 refresh with retry (exactly once)
// - Timeout configuration
// - Response envelope unwrapping
// - Typed AppException mapping
// - Request/response logging (debug mode only)
// - SSL pinning hook (stubbed — enable before production)


import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/api_response.dart';
import '../models/app_exception.dart';
import '../utils/logger.dart';
import 'secure_storage_service.dart';

class ApiClient {
  ApiClient({required this.secureStorage}) {
    _dio = Dio(_baseOptions);
    _setupInterceptors();
    // Extension point: SSL Pinning — enable before production release
    // if (AppConfig.enableSslPinning) _configureSslPinning();
  }

  final SecureStorageService secureStorage;
  late final Dio _dio;
  bool _isRefreshing = false;

  BaseOptions get _baseOptions => BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-App-Platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios'),
          'X-App-Version': '1.0.0',
        },
        responseType: ResponseType.json,
      );

  void _setupInterceptors() {
    // 1. Auth injection interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await secureStorage.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            AppLogger.debug('==================== REQUEST ====================', tag: 'HTTP');
            AppLogger.debug('URL: ${options.uri}', tag: 'HTTP');
            AppLogger.debug('Method: ${options.method}', tag: 'HTTP');
            AppLogger.debug('Headers: ${options.headers}', tag: 'HTTP');
            AppLogger.debug('Body: ${options.data}', tag: 'HTTP');
            AppLogger.debug('=================================================', tag: 'HTTP');
            handler.next(options);
          } catch (e, st) {
            debugPrint("INTERCEPTOR ERROR (onRequest): $e");
            debugPrintStack(stackTrace: st);
            rethrow;
          }
        },
        onResponse: (response, handler) {
          try {
            AppLogger.debug('==================== RESPONSE ====================', tag: 'HTTP');
            AppLogger.debug('URL: ${response.requestOptions.uri}', tag: 'HTTP');
            AppLogger.debug('Status: ${response.statusCode}', tag: 'HTTP');
            // Do NOT print response.data here directly to prevent large JSON freezes
            AppLogger.debug('Body: [OMITTED FROM INTERCEPTOR TO PREVENT CRASH]', tag: 'HTTP');
            AppLogger.debug('==================================================', tag: 'HTTP');
            handler.next(response);
          } catch (e, st) {
            debugPrint("INTERCEPTOR ERROR (onResponse): $e");
            debugPrintStack(stackTrace: st);
            rethrow;
          }
        },
        onError: (error, handler) async {
          try {
            AppLogger.error('==================== ERROR ====================', tag: 'HTTP');
            AppLogger.error('URL: ${error.requestOptions.uri}', tag: 'HTTP');
            AppLogger.error('Method: ${error.requestOptions.method}', tag: 'HTTP');
            AppLogger.error('Exception: ${error.message}', tag: 'HTTP');
            AppLogger.error('Original Error: ${error.error}', tag: 'HTTP');
            AppLogger.error('Timeout Type: ${error.type.name}', tag: 'HTTP');
            AppLogger.error('Stack Trace: ${error.stackTrace}', tag: 'HTTP');
            AppLogger.error('Response Status: ${error.response?.statusCode}', tag: 'HTTP');
            if (error.response?.data != null) {
              final data = error.response!.data;
              if (data is Map) {
                final safeMessage = data['message'] ?? data['error'] ?? data['msg'];
                final safeCode = data['code'] ?? data['errorCode'];
                final safeErrors = data['errors'] ?? data['validationErrors'];
                AppLogger.error('[RAZORPAY ORDER ERROR] status: ${error.response?.statusCode}, errorCode: $safeCode, message: $safeMessage, validationErrors: $safeErrors', tag: 'HTTP');
              } else {
                AppLogger.error('[RAZORPAY ORDER ERROR] status: ${error.response?.statusCode}, body: $data', tag: 'HTTP');
              }
            } else {
              AppLogger.error('Response Body: [EMPTY]', tag: 'HTTP');
            }
            AppLogger.error('===============================================', tag: 'HTTP');

            if (error.response?.statusCode == 401) {
              final reqPath = error.requestOptions.path.toLowerCase();
              final isPinOrAuthEndpoint = reqPath.contains('security-pin') || 
                                          reqPath.contains('mpin') || 
                                          reqPath.contains('auth/login') ||
                                          reqPath.contains('auth/verify');
              if (!isPinOrAuthEndpoint) {
                AppLogger.warning('Token expired or invalid (HTTP 401) — clearing session for path: $reqPath', tag: 'Auth');
                await secureStorage.clearSession();
              } else {
                AppLogger.warning('401 received on authentication/PIN endpoint ($reqPath) — preserving session', tag: 'Auth');
              }
            }

            final isColdStartError = 
                error.type == DioExceptionType.connectionTimeout || 
                error.type == DioExceptionType.receiveTimeout ||
                (error.response?.statusCode != null && [502, 503, 504].contains(error.response?.statusCode));
                
            final hasRetried = error.requestOptions.extra['retried'] == true;

            if (isColdStartError && !hasRetried) {
              AppLogger.warning('Detected possible Render cold start. Retrying request in 2 seconds...', tag: 'HTTP');
              error.requestOptions.extra['retried'] = true;
              await Future.delayed(const Duration(seconds: 2));
              try {
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } catch (retryError) {
                return handler.next(retryError is DioException ? retryError : error);
              }
            }

            handler.next(error);
          } catch (e, st) {
            debugPrint("INTERCEPTOR ERROR (onError): $e");
            debugPrintStack(stackTrace: st);
            rethrow;
          }
        },
      ),
    );

    // 2. Logging interceptor (debug only)
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: false,
          logPrint: (obj) => AppLogger.debug(obj.toString(), tag: 'HTTP'),
          error: true,
        ),
      );
    }
  }

  // ─── Health Check ─────────────────────────────────────────────────
  
  /// Pings the backend to verify connectivity before critical flows (like OTP request)
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health', options: Options(
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Health check failed', tag: 'ApiClient', error: e);
      return false;
    }
  }

  // ─── HTTP Methods ─────────────────────────────────────────────────

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(Object? json)? fromJson,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return ApiResponse<T>.fromJson(response.data!, fromJson);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e, stack) {
      AppLogger.error('GET request failed', tag: 'ApiClient', error: e, stackTrace: stack);
      throw UnknownException.from(e);
    }
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    T Function(Object? json)? fromJson,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: headers != null ? Options(headers: headers) : null,
      );
      return ApiResponse<T>.fromJson(response.data!, fromJson);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e, stack) {
      AppLogger.error('POST request failed', tag: 'ApiClient', error: e, stackTrace: stack);
      throw UnknownException.from(e);
    }
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    Object? data,
    T Function(Object? json)? fromJson,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(path, data: data);
      return ApiResponse<T>.fromJson(response.data!, fromJson);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e, stack) {
      AppLogger.error('PUT request failed', tag: 'ApiClient', error: e, stackTrace: stack);
      throw UnknownException.from(e);
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    Object? data,
    T Function(Object? json)? fromJson,
  }) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(path, data: data);
      return ApiResponse<T>.fromJson(response.data!, fromJson);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e, stack) {
      AppLogger.error('DELETE request failed', tag: 'ApiClient', error: e, stackTrace: stack);
      throw UnknownException.from(e);
    }
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    Object? data,
    T Function(Object? json)? fromJson,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(path, data: data);
      return ApiResponse<T>.fromJson(response.data!, fromJson);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e, stack) {
      AppLogger.error('PATCH request failed', tag: 'ApiClient', error: e, stackTrace: stack);
      throw UnknownException.from(e);
    }
  }

  // ─── Exception Mapping ────────────────────────────────────────────

  String _extractBackendErrorMessage(dynamic data) {
    if (data is! Map) {
      if (data is String && data.trim().isNotEmpty) return data.trim();
      return 'An unexpected error occurred.';
    }

    final map = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);

    // 1. response.data.error (Map with description/message)
    if (map['error'] is Map) {
      final errMap = Map<String, dynamic>.from(map['error'] as Map);
      if (errMap['description'] != null && errMap['description'].toString().trim().isNotEmpty) {
        return errMap['description'].toString().trim();
      }
      if (errMap['message'] != null && errMap['message'].toString().trim().isNotEmpty) {
        return errMap['message'].toString().trim();
      }
    }

    // 2. response.data.details (Map with providerDescription/failureReason)
    if (map['details'] is Map) {
      final details = Map<String, dynamic>.from(map['details'] as Map);
      if (details['providerDescription'] != null && details['providerDescription'].toString().trim().isNotEmpty) {
        return details['providerDescription'].toString().trim();
      }
      if (details['failureReason'] != null && details['failureReason'].toString().trim().isNotEmpty) {
        return details['failureReason'].toString().trim();
      }
      if (details['error'] != null && details['error'].toString().trim().isNotEmpty) {
        return details['error'].toString().trim();
      }
      if (details['message'] != null && details['message'].toString().trim().isNotEmpty) {
        return details['message'].toString().trim();
      }
    }

    // 3. response.data.message
    if (map['message'] != null && map['message'].toString().trim().isNotEmpty) {
      return map['message'].toString().trim();
    }

    // 4. response.data.error string
    if (map['error'] != null && map['error'].toString().trim().isNotEmpty) {
      return map['error'].toString().trim();
    }

    // 5. response.data.reason
    if (map['reason'] != null && map['reason'].toString().trim().isNotEmpty) {
      return map['reason'].toString().trim();
    }

    // 6. response.data.failureReason
    if (map['failureReason'] != null && map['failureReason'].toString().trim().isNotEmpty) {
      return map['failureReason'].toString().trim();
    }

    // 7. response.data.errors[0]
    if (map['errors'] != null) {
      final errors = map['errors'];
      if (errors is List && errors.isNotEmpty) {
        return errors.first.toString().trim();
      }
      if (errors is Map && errors.isNotEmpty) {
        return errors.values.first.toString().trim();
      }
      if (errors is String && errors.trim().isNotEmpty) {
        return errors.trim();
      }
    }

    return 'An unexpected error occurred.';
  }

  AppException _mapDioException(DioException e) {
    AppLogger.error('DioException mapped', tag: 'ApiClient', error: e);

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        AppLogger.error('Network Timeout: ${e.type.name}', tag: 'Network');
        return NetworkException.timeout;

      case DioExceptionType.connectionError:
        final errStr = e.error.toString();
        if (kIsWeb && e.message != null && e.message!.contains('XMLHttpRequest')) {
          AppLogger.error('Server Unreachable (Web/CORS)', tag: 'Network');
          return NetworkException.serverUnreachable;
        }
        if (errStr.contains('Connection refused')) {
          AppLogger.error('Server Unreachable (Connection refused)', tag: 'Network');
          return NetworkException.serverUnreachable;
        }
        if (errStr.contains('Failed host lookup')) {
          AppLogger.error('DNS Failure', tag: 'Network');
          return NetworkException.dnsFailure;
        }
        AppLogger.error('No Internet Connection', tag: 'Network');
        return NetworkException.noConnection;

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        final message = _extractBackendErrorMessage(responseData);
        final code = (responseData is Map) ? responseData['code']?.toString() : null;

        if (statusCode == 401) {
          return AuthException(
            message: message != 'An unexpected error occurred.' ? message : 'Your session has expired. Please log in again.',
            code: code ?? 'SESSION_EXPIRED',
            isSessionExpired: true,
          );
        }
        if (statusCode == 403) {
          return AuthException(
            message: message != 'An unexpected error occurred.' ? message : 'You are not authorized to perform this action.',
            code: code ?? 'UNAUTHORIZED',
            isUnauthorized: true,
          );
        }
        if (statusCode == 402) {
          return TransactionException(
            message: message != 'An unexpected error occurred.' ? message : 'Insufficient wallet balance.',
            code: code ?? 'INSUFFICIENT_BALANCE',
          );
        }
        if (statusCode == 422 || statusCode == 400) {
          final fieldErrors = (responseData is Map && responseData['errors'] is Map)
              ? (responseData['errors'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
              : <String, String>{};
          return ValidationException(
            message: message,
            code: code ?? 'VALIDATION_ERROR',
            fieldErrors: fieldErrors,
          );
        }
        if (statusCode != null && [502, 503, 504].contains(statusCode)) {
          AppLogger.error('Server is waking up (Render cold start) or gateway error: $statusCode', tag: 'Network');
          return NetworkException.serverWakingUp;
        }
        if (statusCode != null && statusCode >= 500) {
          return ServerException(
            message: message,
            statusCode: statusCode,
            code: code,
          );
        }
        return NetworkException(
          message: message,
          statusCode: statusCode,
          code: code,
        );

      case DioExceptionType.cancel:
        return const UnknownException(message: 'Request cancelled');

      case DioExceptionType.unknown:
      case DioExceptionType.badCertificate:
        if (e.error.toString().contains('SocketException')) {
          return NetworkException.noConnection;
        }
        return UnknownException.from(e);
    }
  }
}
