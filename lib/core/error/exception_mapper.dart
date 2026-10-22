import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/error/failure.dart';

/// How repositories turn data-layer exceptions into domain failures.
extension AppExceptionToFailure on AppException {
  Failure toFailure() => switch (this) {
    ServerException(:final message, :final statusCode, :final code) =>
      ServerFailure(message, statusCode: statusCode, code: code),
    NetworkException(:final message) => NetworkFailure(message),
    CacheException(:final message) => CacheFailure(message),
  };
}
