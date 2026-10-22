import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/starter_deck_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/vocabulary_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/remote/vocabulary_remote_data_source.dart';
import 'package:lexico/features/vocabulary/data/models/study_card_row.dart';
import 'package:lexico/features/vocabulary/data/models/word_dto.dart';
import 'package:lexico/features/vocabulary/data/repositories/vocabulary_repository_impl.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fixtures.dart';

class _MockRemote extends Mock implements VocabularyRemoteDataSource {}

class _MockLocal extends Mock implements VocabularyLocalDataSource {}

class _MockStarterDeck extends Mock implements StarterDeckDataSource {}

void main() {
  late _MockRemote remote;
  late _MockLocal local;
  late _MockStarterDeck starterDeck;
  late VocabularyRepositoryImpl repository;

  final now = DateTime(2026, 8, 21, 10);

  setUpAll(() {
    registerFallbackValue(<WordRow>[]);
    registerFallbackValue(now);
    registerFallbackValue(_row().review);
    registerFallbackValue(const WordsCompanion());
    registerFallbackValue(<WordDraft>[]);
    registerFallbackValue(
      const WordDraft(questionExample: '', answerExample: ''),
    );
    registerFallbackValue(
      StudySessionsCompanion.insert(
        startedAt: now,
        endedAt: now,
        reviewedCount: 0,
        correctCount: 0,
        xpEarned: 0,
      ),
    );
  });

  setUp(() {
    remote = _MockRemote();
    local = _MockLocal();
    starterDeck = _MockStarterDeck();
    repository = VocabularyRepositoryImpl(
      remote: remote,
      local: local,
      starterDeck: starterDeck,
      clock: () => now,
    );

    when(() => local.replaceDeck(any(), any(), any())).thenAnswer((_) async {});
    when(local.studiedDeckIds).thenAnswer((_) async => {testDeckId});
  });

  group('syncDecks', () {
    test('replaces the deck with what the word service returns', () async {
      when(() => remote.fetchWords(testDeckId)).thenAnswer(
        (_) async => [testDto(), testDto(id: 'es-frase', question: null)],
      );
      when(local.wordCount).thenAnswer((_) async => 2);

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 2);
      final captured =
          verify(
                () => local.replaceDeck(testDeckId, captureAny(), now),
              ).captured.single
              as List<WordRow>;
      expect(captured.map((row) => row.id), ['es-atardecer', 'es-frase']);
      expect(captured.map((row) => row.position), [0, 1]);
      expect(captured.last.questionShort, isNull);
      verifyNever(starterDeck.load);
    });

    test('keeps the stored deck when the service sends no words', () async {
      when(() => remote.fetchWords(any())).thenAnswer((_) async => []);
      when(local.wordCount).thenAnswer((_) async => 24);

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 24);
      verifyNever(() => local.replaceDeck(any(), any(), any()));
    });

    test('keeps the stored deck when the network is unavailable', () async {
      when(() => remote.fetchWords(any())).thenThrow(const NetworkException());
      when(local.wordCount).thenAnswer((_) async => 24);

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 24);
      verifyNever(starterDeck.load);
      verifyNever(() => local.replaceDeck(any(), any(), any()));
    });

    test('seeds the bundled deck when offline with nothing stored', () async {
      when(() => remote.fetchWords(any())).thenThrow(const NetworkException());
      when(starterDeck.load).thenAnswer((_) async => [testDto()]);

      var stored = 0;
      when(local.wordCount).thenAnswer((_) async => stored);
      when(() => local.replaceDeck(any(), any(), any())).thenAnswer((
        invocation,
      ) async {
        stored = (invocation.positionalArguments[1] as List).length;
      });

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 1);
      verify(starterDeck.load).called(1);
    });

    test('syncs every studied deck, even if one of them fails', () async {
      when(
        local.studiedDeckIds,
      ).thenAnswer((_) async => {'es-food', testDeckId});
      when(
        () => remote.fetchWords('es-food'),
      ).thenThrow(const ServerException('gone', code: 'deck_not_found'));
      when(
        () => remote.fetchWords(testDeckId),
      ).thenAnswer((_) async => [testDto()]);
      when(local.wordCount).thenAnswer((_) async => 1);

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 1);
      verify(() => local.replaceDeck(testDeckId, any(), now)).called(1);
      verifyNever(() => local.replaceDeck('es-food', any(), any()));
    });

    test('does not seed the bundled deck if it is not studied', () async {
      when(local.studiedDeckIds).thenAnswer((_) async => {'es-food'});
      when(() => remote.fetchWords(any())).thenThrow(const NetworkException());
      when(local.wordCount).thenAnswer((_) async => 0);

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 0);
      verifyNever(starterDeck.load);
    });

    test('studies nothing when no deck is chosen', () async {
      when(local.studiedDeckIds).thenAnswer((_) async => {});
      when(local.wordCount).thenAnswer((_) async => 0);

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 0);
      verifyZeroInteractions(remote);
    });

    test('a local database error fails the sync', () async {
      when(() => remote.fetchWords(any())).thenAnswer((_) async => [testDto()]);
      when(
        () => local.replaceDeck(any(), any(), any()),
      ).thenThrow(const CacheException('disk full'));

      final result = await repository.syncDecks();

      expect(result.failureOrNull, const CacheFailure('disk full'));
    });

    test(
      'surfaces a failure when even the bundled deck is unreadable',
      () async {
        when(
          () => remote.fetchWords(any()),
        ).thenThrow(const NetworkException());
        when(local.wordCount).thenAnswer((_) async => 0);
        when(starterDeck.load).thenThrow(const CacheException('no asset'));

        final result = await repository.syncDecks();

        expect(result.failureOrNull, isA<CacheFailure>());
      },
    );
  });

  group('setDeckStudied', () {
    setUp(() {
      when(
        () => local.setDeckStudied(any(), studied: any(named: 'studied')),
      ).thenAnswer((_) async {});
    });

    test('turning a deck on fetches its words straight away', () async {
      when(
        () => remote.fetchWords('es-food'),
      ).thenAnswer((_) async => [testDto(id: 'es-pan')]);

      final result = await repository.setDeckStudied('es-food', studied: true);

      expect(result.isSuccess, isTrue);
      verify(() => local.setDeckStudied('es-food', studied: true)).called(1);
      final rows =
          verify(
                () => local.replaceDeck('es-food', captureAny(), now),
              ).captured.single
              as List<WordRow>;
      expect(rows.single.deckId, 'es-food');
    });

    test('turning a deck on still succeeds offline', () async {
      when(() => remote.fetchWords(any())).thenThrow(const NetworkException());

      final result = await repository.setDeckStudied('es-food', studied: true);

      expect(result.isSuccess, isTrue);
      verifyNever(() => local.replaceDeck(any(), any(), any()));
    });

    test('turning a deck off touches neither words nor network', () async {
      final result = await repository.setDeckStudied(
        testDeckId,
        studied: false,
      );

      expect(result.isSuccess, isTrue);
      verify(() => local.setDeckStudied(testDeckId, studied: false)).called(1);
      verifyZeroInteractions(remote);
      verifyNever(() => local.replaceDeck(any(), any(), any()));
    });

    test('reports a failed save', () async {
      when(
        () => local.setDeckStudied(any(), studied: any(named: 'studied')),
      ).thenThrow(const CacheException('disk full'));

      final result = await repository.setDeckStudied('es-food', studied: true);

      expect(result.failureOrNull, const CacheFailure('disk full'));
    });
  });

  group('addWord', () {
    const word = WordDraft(
      questionShort: 'el pan',
      questionExample: 'Compro pan cada mañana.',
      answerExample: 'I buy bread every morning.',
    );

    test('adds the word and refreshes a studied deck', () async {
      when(
        () => remote.addWords(testDeckId, [word]),
      ).thenAnswer((_) async => [testDto(id: 'es-pan')]);
      when(
        () => remote.fetchWords(testDeckId),
      ).thenAnswer((_) async => [testDto(), testDto(id: 'es-pan')]);

      final added = (await repository.addWord(testDeckId, word)).valueOrNull!;

      expect(added.id, 'es-pan');
      expect(added.deckId, testDeckId);
      verify(() => local.replaceDeck(testDeckId, any(), now)).called(1);
    });

    test('leaves the device alone for a deck not studied', () async {
      when(
        () => remote.addWords('es-food', [word]),
      ).thenAnswer((_) async => [testDto(id: 'es-pan')]);

      final result = await repository.addWord('es-food', word);

      expect(result.isSuccess, isTrue);
      verifyNever(() => remote.fetchWords(any()));
      verifyNever(() => local.replaceDeck(any(), any(), any()));
    });

    test('still succeeds when storing it locally fails', () async {
      when(
        () => remote.addWords(any(), any()),
      ).thenAnswer((_) async => [testDto(id: 'es-pan')]);
      when(
        () => remote.fetchWords(any()),
      ).thenAnswer((_) async => [testDto(id: 'es-pan')]);
      when(
        () => local.replaceDeck(any(), any(), any()),
      ).thenThrow(const CacheException('disk full'));

      final result = await repository.addWord(testDeckId, word);

      expect(result.valueOrNull?.id, 'es-pan');
    });

    test('reports a refused word', () async {
      when(() => remote.addWords(any(), any())).thenThrow(
        const ServerException(
          'taken',
          statusCode: 409,
          code: 'question_examples_taken',
        ),
      );

      final result = await repository.addWord(testDeckId, word);

      expect(
        result.failureOrNull,
        const ServerFailure(
          'taken',
          statusCode: 409,
          code: 'question_examples_taken',
        ),
      );
      verifyNever(() => local.replaceDeck(any(), any(), any()));
    });
  });

  group('editWord', () {
    final word = testWord(id: 'es-pan');
    const draft = WordDraft(
      questionShort: 'el pan',
      answerShort: 'bread, loaf',
      questionExample: 'Compro pan cada mañana.',
      answerExample: 'I buy bread every morning.',
    );

    setUp(() {
      when(() => local.updateWord(any(), any())).thenAnswer((_) async {});
    });

    test('saves on the service and updates the stored copy', () async {
      when(
        () => remote.editWord('es-pan', draft),
      ).thenAnswer((_) async => testDto(id: 'es-pan', shows: 2));

      final saved = (await repository.editWord(word, draft)).valueOrNull!;

      expect(saved.id, 'es-pan');
      expect(saved.deckId, testDeckId);
      expect(saved.showsCount, 2);
      final update =
          verify(() => local.updateWord('es-pan', captureAny())).captured.single
              as WordsCompanion;
      expect(update.showsCount.value, 2);
    });

    test('still succeeds when the stored copy cannot be updated', () async {
      when(
        () => remote.editWord(any(), any()),
      ).thenAnswer((_) async => testDto(id: 'es-pan'));
      when(
        () => local.updateWord(any(), any()),
      ).thenThrow(const CacheException('disk full'));

      final result = await repository.editWord(word, draft);

      expect(result.valueOrNull?.id, 'es-pan');
    });

    test('reports a refused edit and leaves the device alone', () async {
      when(() => remote.editWord(any(), any())).thenThrow(
        const ServerException('gone', statusCode: 404, code: 'word_not_found'),
      );

      final result = await repository.editWord(word, draft);

      expect(
        result.failureOrNull,
        const ServerFailure('gone', statusCode: 404, code: 'word_not_found'),
      );
      verifyNever(() => local.updateWord(any(), any()));
    });
  });

  group('deckWords', () {
    test('comes from the word service, in order', () async {
      when(() => remote.fetchWords('es-food')).thenAnswer(
        (_) async => [
          testDto(id: 'es-pan', shows: 3, successes: 2, failures: 1),
          testDto(id: 'es-sal', question: null),
        ],
      );

      final words = (await repository.deckWords('es-food')).valueOrNull!;

      expect(words.map((w) => w.id), ['es-pan', 'es-sal']);
      expect(words.first.deckId, 'es-food');
      expect(words.first.showsCount, 3);
      expect(words.last.isSentence, isTrue);
      verifyNever(() => local.wordsOfDeck(any()));
    });

    test('falls back to the stored copy when offline', () async {
      when(() => remote.fetchWords(any())).thenThrow(const NetworkException());
      when(
        () => local.wordsOfDeck(testDeckId),
      ).thenAnswer((_) async => [_row().word]);

      final words = (await repository.deckWords(testDeckId)).valueOrNull!;

      expect(words.single.id, 'es-atardecer');
    });

    test('reports the network problem when nothing is stored', () async {
      when(
        () => remote.fetchWords(any()),
      ).thenThrow(const NetworkException('offline'));
      when(() => local.wordsOfDeck(any())).thenAnswer((_) async => []);

      final result = await repository.deckWords('es-food');

      expect(result.failureOrNull, const NetworkFailure('offline'));
    });

    test('does not show stored words of a deleted deck', () async {
      when(() => remote.fetchWords(any())).thenThrow(
        const ServerException(
          'No deck.',
          statusCode: 404,
          code: 'deck_not_found',
        ),
      );

      final result = await repository.deckWords(testDeckId);

      expect(
        result.failureOrNull,
        const ServerFailure(
          'No deck.',
          statusCode: 404,
          code: 'deck_not_found',
        ),
      );
      verifyNever(() => local.wordsOfDeck(any()));
    });
  });

  group('dueCards', () {
    test('maps joined rows into study cards', () async {
      when(
        () => local.dueCards(now: now, limit: 8),
      ).thenAnswer((_) async => [_row()]);

      final result = await repository.dueCards(limit: 8);
      final cards = result.valueOrNull!;

      expect(cards, hasLength(1));
      expect(cards.single.word.question, 'el atardecer');
      expect(cards.single.review.dueAt, now);
    });

    test('reports a cache failure', () async {
      when(
        () => local.dueCards(
          now: any(named: 'now'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(const CacheException('disk full'));

      final result = await repository.dueCards(limit: 8);

      expect(result.failureOrNull, const CacheFailure('disk full'));
    });
  });

  test('upcomingCards maps the rows of words not yet due', () async {
    when(
      () => local.upcomingCards(now: now, limit: 8),
    ).thenAnswer((_) async => [_row()]);

    final cards = (await repository.upcomingCards(limit: 8)).valueOrNull!;

    expect(cards.single.word.question, 'el atardecer');
  });

  group('saveReview', () {
    final state = ReviewState.fresh('es-atardecer', now);

    setUp(() {
      when(() => local.saveReview(any())).thenAnswer((_) async {});
      when(() => local.updateWord(any(), any())).thenAnswer((_) async {});
    });

    test('stores locally, then reports the answer to the service', () async {
      when(
        () => remote.submitReview('es-atardecer', correct: true),
      ).thenAnswer((_) async => testDto(shows: 4, successes: 3, failures: 1));

      final result = await repository.saveReview(state, correct: true);
      await untilCalled(() => local.updateWord(any(), any()));

      expect(result.valueOrNull, state);
      verify(() => local.saveReview(any())).called(1);
      final update =
          verify(
                () => local.updateWord('es-atardecer', captureAny()),
              ).captured.single
              as WordsCompanion;
      expect(update.showsCount.value, 4);
      expect(update.successesCount.value, 3);
      expect(update.failuresCount.value, 1);
    });

    test('does not wait for the service to answer', () async {
      final pending = Completer<WordDto>();
      when(
        () => remote.submitReview(any(), correct: any(named: 'correct')),
      ).thenAnswer((_) => pending.future);

      final result = await repository.saveReview(state, correct: false);

      expect(result.valueOrNull, state);
      verify(() => remote.submitReview('es-atardecer', correct: false));
    });

    test('still succeeds when the report fails', () async {
      when(
        () => remote.submitReview(any(), correct: any(named: 'correct')),
      ).thenThrow(const NetworkException());

      final result = await repository.saveReview(state, correct: true);
      await pumpEventQueue();

      expect(result.valueOrNull, state);
      verifyNever(() => local.updateWord(any(), any()));
    });

    test('reports nothing when the local save fails', () async {
      when(
        () => local.saveReview(any()),
      ).thenThrow(const CacheException('disk full'));

      final result = await repository.saveReview(state, correct: true);
      await pumpEventQueue();

      expect(result.failureOrNull, const CacheFailure('disk full'));
      verifyZeroInteractions(remote);
    });
  });

  test('learnerStats combines the counters and the streak', () async {
    when(() => local.countDue(now)).thenAnswer((_) async => 8);
    when(local.wordCount).thenAnswer((_) async => 600);
    when(local.countKnown).thenAnswer((_) async => 418);
    when(local.countShaky).thenAnswer((_) async => 37);
    when(local.answerTotals).thenAnswer(
      (_) async => const AnswerTotalsRow(timesSeen: 100, timesCorrect: 92),
    );
    when(local.totalXp).thenAnswer((_) async => 5040);
    when(
      local.sessionDays,
    ).thenAnswer((_) async => [now, now.subtract(const Duration(days: 1))]);

    final stats = (await repository.learnerStats()).valueOrNull!;

    expect(stats.dueCount, 8);
    expect(stats.wordCount, 600);
    expect(stats.knownCount, 418);
    expect(stats.shakyCount, 37);
    expect(stats.accuracyPercent, 92);
    expect(stats.streakDays, 2);
    expect(stats.level, 6);
    expect(stats.xpIntoLevel, 540);
  });

  test('logSession stores the sitting and returns the new streak', () async {
    when(() => local.insertSession(any())).thenAnswer((_) async {});
    when(local.sessionDays).thenAnswer((_) async => [now]);

    final result = await repository.logSession(
      startedAt: now.subtract(const Duration(minutes: 4)),
      endedAt: now,
      reviewedCount: 8,
      correctCount: 7,
      xpEarned: 84,
    );

    expect(result.valueOrNull, 1);
    verify(() => local.insertSession(any())).called(1);
  });
}

StudyCardRow _row() {
  final now = DateTime(2026, 8, 21, 10);
  return StudyCardRow(
    word: const WordRow(
      id: 'es-atardecer',
      deckId: testDeckId,
      position: 0,
      questionShort: 'el atardecer',
      answerShort: 'sunset',
      questionExample: 'Caminamos por la playa al atardecer.',
      answerExample: 'We walked along the beach at sunset.',
      showsCount: 0,
      successesCount: 0,
      failuresCount: 0,
    ),
    review: ReviewRow(
      wordId: 'es-atardecer',
      repetitions: 0,
      intervalDays: 0,
      easeFactor: ReviewState.defaultEaseFactor,
      dueAt: now,
      lapses: 0,
      timesSeen: 0,
      timesCorrect: 0,
    ),
  );
}
