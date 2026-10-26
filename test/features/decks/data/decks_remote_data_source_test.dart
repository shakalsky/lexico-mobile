import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/features/decks/data/datasources/decks_remote_data_source.dart';

import '../../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late DecksRemoteDataSourceImpl remote;

  setUp(() {
    adapter = FakeHttpAdapter(() => jsonReply(200, {'decks': <Object>[]}));
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    remote = DecksRemoteDataSourceImpl(dio);
  });

  test('reads every deck in the order served', () async {
    adapter.reply = () => jsonReply(200, {
      'decks': [
        {
          'id': 'es-en-core',
          'name': 'Core',
          'language': 'Español',
          'created_at': '2026-10-08T09:12:59.649Z',
        },
        {
          'id': 'es-food',
          'name': 'Food',
          'language': 'Español',
          'created_at': '2026-10-09T15:31:46.473Z',
        },
      ],
    });

    final decks = await remote.fetchDecks();

    expect(adapter.lastRequest!.method, 'GET');
    expect(adapter.lastRequest!.path, '/decks');
    expect(decks.map((d) => d.id), ['es-en-core', 'es-food']);
    expect(decks.first.name, 'Core');
    expect(decks.first.createdAt, DateTime.utc(2026, 10, 8, 9, 12, 59, 649));
  });

  test('handles a service with no decks', () async {
    expect(await remote.fetchDecks(), isEmpty);
  });

  test('rejects a deck with an unreadable date', () async {
    adapter.reply = () => jsonReply(200, {
      'decks': [
        {
          'id': 'x',
          'name': 'X',
          'language': 'Español',
          'created_at': 'yesterday',
        },
      ],
    });

    await expectLater(remote.fetchDecks(), throwsA(isA<ServerException>()));
  });

  test('rejects a reply without a decks list', () async {
    adapter.reply = () => jsonReply(200, {'deck': <String, Object>{}});

    await expectLater(remote.fetchDecks(), throwsA(isA<ServerException>()));
  });

  test('reports an unreachable server as a network problem', () async {
    adapter.reply = () => throw DioException.connectionError(
      requestOptions: RequestOptions(),
      reason: 'refused',
    );

    await expectLater(remote.fetchDecks(), throwsA(isA<NetworkException>()));
  });

  test('creates a deck and returns what the service stored', () async {
    adapter.reply = () => jsonReply(201, {
      'deck': {
        'id': '6f1c0a2e-0000-4000-8000-000000000000',
        'name': 'Food',
        'language': 'Español',
        'created_at': '2026-10-22T08:00:00.000Z',
      },
    });

    final deck = await remote.createDeck(
      id: '6f1c0a2e-0000-4000-8000-000000000000',
      name: 'Food',
      language: 'Español',
    );

    final request = adapter.lastRequest!;
    expect(request.method, 'POST');
    expect(request.path, '/decks');
    expect(request.data, {
      'id': '6f1c0a2e-0000-4000-8000-000000000000',
      'name': 'Food',
      'language': 'Español',
    });
    expect(request.contentType, startsWith(Headers.jsonContentType));
    expect(deck.id, '6f1c0a2e-0000-4000-8000-000000000000');
    expect(deck.name, 'Food');
  });

  test('surfaces a rejected deck with its message', () async {
    adapter.reply = () => jsonReply(400, {
      'statusCode': 400,
      'code': 'FST_ERR_VALIDATION',
      'error': 'Bad Request',
      'message': 'body/name must match pattern',
    });

    await expectLater(
      remote.createDeck(id: 'x', name: ' ', language: 'Español'),
      throwsA(
        isA<ServerException>()
            .having((e) => e.code, 'code', 'FST_ERR_VALIDATION')
            .having(
              (e) => e.message,
              'message',
              'body/name must match pattern',
            ),
      ),
    );
  });
}
