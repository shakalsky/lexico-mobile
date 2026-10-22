import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers every request with a canned reply and remembers what was sent.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.reply);

  ResponseBody Function() reply;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return reply();
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON response with the given status.
ResponseBody jsonReply(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
