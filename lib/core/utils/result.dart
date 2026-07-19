// lib/core/utils/result.dart
// Sealed Result<T, E> union type for safe error propagation.
// Use this as the return type for all repository methods instead of throwing exceptions.
// UI layers unwrap Result via pattern matching to handle both success and error states explicitly.

sealed class Result<T, E extends Exception> {
  const Result();

  /// Returns true if the result represents success.
  bool get isSuccess => this is Success<T, E>;

  /// Returns true if the result represents a failure.
  bool get isFailure => this is Failure<T, E>;

  /// Extracts the success value, or null if this is a failure.
  T? get valueOrNull => switch (this) {
        Success<T, E>(value: final v) => v,
        Failure<T, E>() => null,
      };

  /// Extracts the error, or null if this is a success.
  E? get errorOrNull => switch (this) {
        Success<T, E>() => null,
        Failure<T, E>(error: final e) => e,
      };

  /// Maps the success value to a new type.
  Result<R, E> map<R>(R Function(T value) transform) => switch (this) {
        Success<T, E>(value: final v) => Success(transform(v)),
        Failure<T, E>(error: final e) => Failure(e),
      };

  /// Transforms the success value into a new Result (flatMap/chain).
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform) =>
      switch (this) {
        Success<T, E>(value: final v) => transform(v),
        Failure<T, E>(error: final e) => Failure(e),
      };

  /// Execute a callback on success value (side effects).
  Result<T, E> onSuccess(void Function(T value) action) {
    if (this case Success<T, E>(value: final v)) action(v);
    return this;
  }

  /// Execute a callback on failure error (side effects like logging).
  Result<T, E> onFailure(void Function(E error) action) {
    if (this case Failure<T, E>(error: final e)) action(e);
    return this;
  }

  /// Get value or provide a default.
  T getOrElse(T defaultValue) => valueOrNull ?? defaultValue;

  /// Get value or compute a fallback.
  T getOrElseCompute(T Function(E error) onError) => switch (this) {
        Success<T, E>(value: final v) => v,
        Failure<T, E>(error: final e) => onError(e),
      };
}

/// Represents a successful result with a value.
final class Success<T, E extends Exception> extends Result<T, E> {
  const Success(this.value);
  final T value;

  @override
  String toString() => 'Success($value)';
}

/// Represents a failed result with an error.
final class Failure<T, E extends Exception> extends Result<T, E> {
  const Failure(this.error);
  final E error;

  @override
  String toString() => 'Failure($error)';
}
