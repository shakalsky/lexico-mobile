import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/features/vocabulary/data/datasources/remote/vocabulary_remote_data_source.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';

import '../../../../helpers/fake_http_adapter.dart';

Map<String, dynamic> _wordJson({
  String id = 'es-pan',
  String? questionShort = 'el pan',
  int shows = 0,
}) => {
  'id': id,
  'question_short': questionShort,
  'answer_short': 'bread',
  'question_example': 'Compro pan cada mañana.',
  'answer_example': 'I buy bread every morning.',
  'shows_count': shows,
  'successes_count': shows,
  'failures_count': 0,
};

void main() {
  late FakeHttpAdapter adapter;
  late VocabularyRemoteDataSourceImpl remote;

  setUp(() {
    adapter = FakeHttpAdapter(() => jsonReply(200, {'words': <Object>[]}));
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
      ..httpClientAdapter = adapter;
    remote = VocabularyRemoteDataSourceImpl(dio);
  });

  group('fetchWords', () {
    test('reads the words in order, including sentence cards', () async {
      adapter.reply = () => jsonReply(200, {
        'words': [_wordJson(), _wordJson(id: 'es-sal', questionShort: null)],
      });

      final words = await remote.fetchWords('es-food');

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/decks/es-food/words');
      expect(words.map((w) => w.id), ['es-pan', 'es-sal']);
      expect(words.first.questionShort, 'el pan');
      expect(words.last.questionShort, isNull);
      expect(words.first.answerExample, 'I buy bread every morning.');
    });

    test('URL-encodes the deck id', () async {
      await remote.fetchWords('es food/ñ');

      expect(adapter.lastRequest!.path, '/decks/es%20food%2F%C3%B1/words');
    });

    test('turns an API error into a coded server exception', () async {
      adapter.reply = () => jsonReply(404, {
        'error': 'deck_not_found',
        'message': 'Deck es-food not found.',
      });

      await expectLater(
        remote.fetchWords('es-food'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 404)
              .having((e) => e.code, 'code', 'deck_not_found')
              .having((e) => e.message, 'message', 'Deck es-food not found.'),
        ),
      );
    });

    test('reads the code of a request error', () async {
      adapter.reply = () => jsonReply(400, {
        'statusCode': 400,
        'code': 'FST_ERR_VALIDATION',
        'error': 'Bad Request',
        'message': 'params/deckId must NOT have fewer than 1 characters',
      });

      await expectLater(
        remote.fetchWords('x'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            'FST_ERR_VALIDATION',
          ),
        ),
      );
    });

    test('rejects a word with a missing field', () async {
      adapter.reply = () => jsonReply(200, {
        'words': [_wordJson()..remove('question_example')],
      });

      await expectLater(
        remote.fetchWords('es-food'),
        throwsA(isA<ServerException>()),
      );
    });

    test('reports an unreachable server as a network problem', () async {
      adapter.reply = () => throw DioException.connectionError(
        requestOptions: RequestOptions(),
        reason: 'refused',
      );

      await expectLater(
        remote.fetchWords('es-food'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('addWords', () {
    test(
      'posts the words with their ids and returns them as created',
      () async {
        adapter.reply = () => jsonReply(201, {
          'words': [_wordJson()],
        });

        final created = await remote.addWords('es food', const [
          (
            id: 'es-pan',
            draft: WordDraft(
              questionShort: 'el pan',
              answerShort: 'bread',
              questionExample: 'Compro pan cada mañana.',
              answerExample: 'I buy bread every morning.',
            ),
          ),
          (
            id: 'es-sal',
            draft: WordDraft(
              questionExample: '¿Me pasas la sal?',
              answerExample: 'Can you pass me the salt?',
            ),
          ),
        ]);

        final request = adapter.lastRequest!;
        expect(request.method, 'POST');
        expect(request.path, '/decks/es%20food/words');
        expect(request.data, {
          'words': [
            {
              'id': 'es-pan',
              'question_short': 'el pan',
              'answer_short': 'bread',
              'question_example': 'Compro pan cada mañana.',
              'answer_example': 'I buy bread every morning.',
            },
            {
              'id': 'es-sal',
              'question_short': null,
              'answer_short': null,
              'question_example': '¿Me pasas la sal?',
              'answer_example': 'Can you pass me the salt?',
            },
          ],
        });
        expect(created.single.id, 'es-pan');
      },
    );

    test('surfaces a sentence already in the deck', () async {
      adapter.reply = () => jsonReply(409, {
        'error': 'question_examples_taken',
        'message': 'Question examples already in this deck: "x".',
      });

      await expectLater(
        remote.addWords('es-food', const [
          (id: 'w', draft: WordDraft(questionExample: 'x', answerExample: 'y')),
        ]),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            'question_examples_taken',
          ),
        ),
      );
    });
  });

  group('editWord', () {
    test('patches all four text fields and returns the saved word', () async {
      adapter.reply = () => jsonReply(200, {'word': _wordJson(shows: 2)});

      final saved = await remote.editWord(
        'es/pan',
        const WordDraft(
          questionShort: 'el pan',
          questionExample: 'Compro pan cada mañana.',
          answerExample: 'I buy bread every morning.',
        ),
      );

      final request = adapter.lastRequest!;
      expect(request.method, 'PATCH');
      expect(request.path, '/words/es%2Fpan');
      expect(request.data, {
        'question_short': 'el pan',
        'answer_short': null,
        'question_example': 'Compro pan cada mañana.',
        'answer_example': 'I buy bread every morning.',
      });
      expect(saved.showsCount, 2);
    });

    test('surfaces a sentence another word has', () async {
      adapter.reply = () => jsonReply(409, {
        'error': 'question_example_taken',
        'message': 'Another word has it.',
      });

      await expectLater(
        remote.editWord(
          'es-pan',
          const WordDraft(questionExample: 'x', answerExample: 'y'),
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            'question_example_taken',
          ),
        ),
      );
    });
  });

  group('submitReview', () {
    test('posts the answer as JSON and returns the counted word', () async {
      adapter.reply = () => jsonReply(200, {'word': _wordJson(shows: 1)});

      final word = await remote.submitReview('es-pan', correct: true);

      final request = adapter.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, '/words/es-pan/reviews');
      expect(request.data, {'correct': true});
      expect(request.contentType, startsWith(Headers.jsonContentType));
      expect(word.showsCount, 1);
      expect(word.successesCount, 1);
    });

    test('surfaces an unknown word', () async {
      adapter.reply = () => jsonReply(404, {
        'error': 'word_not_found',
        'message': 'Word es-pan not found.',
      });

      await expectLater(
        remote.submitReview('es-pan', correct: false),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            'word_not_found',
          ),
        ),
      );
    });
  });
}
