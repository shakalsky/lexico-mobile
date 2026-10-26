import 'package:lexico/core/error/failure.dart' show Failure;

/// Data-layer exceptions. They never escape the repository: implementations
/// translate them into [Failure]s before returning to the domain.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() {
    final name = switch (this) {
      ServerException() => 'ServerException',
      NetworkException() => 'NetworkException',
      CacheException() => 'CacheException',
    };
    return '$name: $message';
  }
}

final class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode, this.code});

  final int? statusCode;

  /// The API's machine-readable error, e.g. `deck_not_found` or
  /// `FST_ERR_VALIDATION`, when the response carried one.
  final String? code;
}

final class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network unreachable.',
    this.mayHaveArrived = false,
  ]);

  /// True when the request may have reached the service before the
  /// connection failed, e.g. a reply that timed out. Calls that are not safe
  /// to repeat must not be retried then.
  final bool mayHaveArrived;
}

final class CacheException extends AppException {
  const CacheException([super.message = 'Local storage failed.']);
}
