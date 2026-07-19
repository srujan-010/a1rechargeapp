// lib/core/models/api_response.dart
// Generic API response envelope matching the backend JSON structure:
//   { "success": true, "message": "...", "data": {...}, "meta": {...} }
// All repository implementations must unwrap this before returning domain models.

class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.meta,
    this.errors,
  });

  final bool success;
  final String message;
  final T? data;
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? errors;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: fromJsonT != null && json['data'] != null
          ? fromJsonT(json['data'])
          : null,
      meta: json['meta'] as Map<String, dynamic>?,
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson(Object? Function(T value)? toJsonT) {
    return {
      'success': success,
      'message': message,
      if (data != null && toJsonT != null) 'data': toJsonT(data as T),
      if (meta != null) 'meta': meta,
      if (errors != null) 'errors': errors,
    };
  }

  @override
  String toString() =>
      'ApiResponse(success: $success, message: $message)';
}

/// Paginated response meta info from the backend.
class PaginationMeta {
  const PaginationMeta({
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.perPage,
    required this.hasMore,
  });

  final int currentPage;
  final int totalPages;
  final int totalCount;
  final int perPage;
  final bool hasMore;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 1,
      totalCount: json['totalCount'] as int? ?? 0,
      perPage: json['perPage'] as int? ?? 20,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

/// Paginated API response wrapper.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.meta,
  });

  final List<T> items;
  final PaginationMeta meta;
}
