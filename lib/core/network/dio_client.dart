import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/network/api_config.dart';

/// Builds the single [Dio] instance the data layer talks through.
abstract final class DioClient {
  static Dio create({required String baseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: const {'Accept': 'application/json'},
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor());
    }

    return dio;
  }
}

/// Turns a [DioException] into the data layer's own exception vocabulary.
///
/// Only failures to connect are known to have sent nothing; every other
/// network failure may have reached the service.
AppException mapDioException(DioException error) => switch (error.type) {
  DioExceptionType.connectionTimeout => const NetworkException(
    'The word service took too long to answer.',
  ),
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout ||
  DioExceptionType.transformTimeout => const NetworkException(
    'The word service took too long to answer.',
    true,
  ),
  DioExceptionType.connectionError => NetworkException(
    error.message ?? 'Could not reach the word service.',
  ),
  DioExceptionType.unknown => NetworkException(
    error.message ?? 'Could not reach the word service.',
    true,
  ),
  DioExceptionType.badCertificate => const NetworkException(
    'The word service presented an invalid certificate.',
  ),
  DioExceptionType.cancel => const NetworkException('Request cancelled.', true),
  DioExceptionType.badResponse => _serverException(error.response),
};

/// Reads the API's error body. Every error has a `message`; request errors
/// carry their name in `code`, API errors in `error` (with no `statusCode`).
ServerException _serverException(Response<dynamic>? response) {
  final status = response?.statusCode;
  final body = response?.data;
  final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};

  final message = map['message'];
  final code =
      map['code'] ?? (map.containsKey('statusCode') ? null : map['error']);

  return ServerException(
    message is String ? message : 'The word service answered with $status.',
    statusCode: status,
    code: code is String ? code : null,
  );
}
