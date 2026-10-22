import 'package:dio/dio.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/network/dio_client.dart';

/// Runs one API call so that every failure leaves it as an [AppException].
Future<T> guardRequest<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (error) {
    throw mapDioException(error);
    // A bad payload surfaces as a TypeError from the casts in fromJson.
    // ignore: avoid_catching_errors
  } on TypeError catch (error) {
    throw ServerException('The word service sent a malformed reply: $error');
  }
}
