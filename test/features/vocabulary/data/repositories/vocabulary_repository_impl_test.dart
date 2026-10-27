import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/starter_deck_data_source.dart';
import 'package:lexico/features/vocabulary/data/mappers/vocabulary_mappers.dart';
import 'package:lexico/features/vocabulary/data/models/pending_change.dart';
import 'package:lexico/features/vocabulary/data/repositories/vocabulary_repository_impl.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/offline_harness.dart';

class _MockStarterDeck extends Mock implements StarterDeckDataSource {}

const _pan = WordDraft(
  questionShort: 'el pan',
  answerShort: 'bread',
  questionExample: 'Compro pan cada mañana.',
  answerExample: 'I buy bread every morning.',
);

void main() {
  late OfflineHarness h;
  late _MockStarterDeck starterDeck;
  late VocabularyRepositoryImpl repository;
  var nextId = 0;

  setUpAll(OfflineHarness.registerFallbacks);

  setUp(() {
    h = OfflineHarness();
    starterDeck = _MockStarterDeck();
    nextId = 0;
    repository = VocabularyRepositoryImpl(
      local: h.local,
      decksLocal: h.decksLocal,
      pending: h.pending,
      transaction: h.transaction,
      sync: h.sync,
      starterDeck: starterDeck,
      clock: () => h.now,
      newId: () => 'new-${++nextId}',
    );
  });

  tearDown(() => h.close());

  /// Stores [deckId] as if it had been synced, with words [ids].
  Future<void> storeDeck(String deckId, List<String> ids) =>
      h.local.replaceDeck(
        deckId,
        deckRows(deckId, [
          for (final id in ids) testDto(id: id, example: 'Ejemplo $id.'),
        ]),
        h.now,
      );

  Future<List<PendingChange>> queued() async {
    final changes = <PendingChange>[];
    for (final row in await h.db.select(h.db.pendingChanges).get()) {
      changes.add(
        PendingChange.fromStored(
          kind: row.kind,
          deckId: row.deckId,
          payload: jsonDecode(row.payload) as Map<String, dynamic>,
        ),
      );
    }
    return changes;
  }

  group('syncDecks', () {
    test('stores what the word service has for each studied deck', () async {
      when(
        () => h.wordsRemote.fetchWords(testDeckId),
      ).thenAnswer((_) async => [testDto(), testDto(id: 'es-frase')]);

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 2);
      verifyNever(starterDeck.load);
    });

    test('keeps the stored words when offline', () async {
      await storeDeck(testDeckId, ['a', 'b']);

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 2);
      verifyNever(starterDeck.load);
    });

    test(
      'seeds the bundled deck, and its tile, when offline and empty',
      () async {
        when(starterDeck.load).thenAnswer(
          (_) async => StarterDeck(
            name: testDeckId,
            language: 'Español',
            words: [testDto()],
          ),
        );

        final result = await repository.syncDecks();

        expect(result.valueOrNull, 1);
        final decks = await h.decksLocal.decks();
        expect(decks.single.id, testDeckId);
        expect(decks.single.language, 'Español');
      },
    );

    test('does not seed the bundled deck if it is not studied', () async {
      await h.local.setDeckStudied(testDeckId, studied: false);

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 0);
      verifyNever(starterDeck.load);
    });

    test('sends changes made offline before refreshing', () async {
      h.acceptChanges();
      await storeDeck(testDeckId, ['a']);
      await repository.addWord(testDeckId, _pan);
      h.goOffline();
      await h.sync.push();
      h.acceptChanges();
      when(
        () => h.wordsRemote.fetchWords(testDeckId),
      ).thenAnswer((_) async => [testDto(id: 'a'), testDto(id: 'new-1')]);

      await repository.syncDecks();

      verifyInOrder([
        () => h.wordsRemote.addWords(testDeckId, any()),
        () => h.wordsRemote.fetchWords(testDeckId),
      ]);
      expect(await h.pending.count(), 0);
    });

    test('a deck the service no longer has is removed for good', () async {
      await storeDeck(testDeckId, ['a']);
      when(() => h.wordsRemote.fetchWords(any())).thenThrow(
        const ServerException(
          'No deck.',
          statusCode: 404,
          code: 'deck_not_found',
        ),
      );

      final result = await repository.syncDecks();

      expect(result.valueOrNull, 0);
      // Gone from the service, so the bundled copy isn't brought back.
      verifyNever(starterDeck.load);
    });

    test(
      'surfaces a failure when even the bundled deck is unreadable',
      () async {
        when(starterDeck.load).thenThrow(const CacheException('no asset'));

        final result = await repository.syncDecks();

        expect(result.failureOrNull, const CacheFailure('no asset'));
      },
    );
  });

  group('setDeckStudied', () {
    test('turning a deck on fetches its words straight away', () async {
      when(
        () => h.wordsRemote.fetchWords('es-food'),
      ).thenAnswer((_) async => [testDto(id: 'es-pan')]);

      final result = await repository.setDeckStudied('es-food', studied: true);

      expect(result.isSuccess, isTrue);
      expect(await h.local.studiedDeckIds(), contains('es-food'));
      expect((await h.local.wordsOfDeck('es-food')).single.id, 'es-pan');
    });

    test('turning a deck on still succeeds offline', () async {
      final result = await repository.setDeckStudied('es-food', studied: true);

      expect(result.isSuccess, isTrue);
      expect(await h.local.studiedDeckIds(), contains('es-food'));
    });

    test('turning a deck off never touches the network', () async {
      final result = await repository.setDeckStudied(
        testDeckId,
        studied: false,
      );

      expect(result.isSuccess, isTrue);
      verifyZeroInteractions(h.wordsRemote);
    });
  });

  group('deckWords', () {
    test('reads the stored words in order, without the network', () async {
      await storeDeck('es-food', ['es-pan', 'es-sal']);

      final words = (await repository.deckWords('es-food')).valueOrNull!;

      expect(words.map((w) => w.id), ['es-pan', 'es-sal']);
      expect(words.first.deckId, 'es-food');
      verifyZeroInteractions(h.wordsRemote);
    });
  });

  group('refreshDeckWords', () {
    test('stores and returns the service copy', () async {
      when(() => h.wordsRemote.fetchWords('es-food')).thenAnswer(
        (_) async => [
          testDto(id: 'es-pan', shows: 3, successes: 2, failures: 1),
        ],
      );

      final words = (await repository.refreshDeckWords('es-food')).valueOrNull!;

      expect(words.single.showsCount, 3);
      expect(await h.local.wordsOfDeck('es-food'), hasLength(1));
    });

    test('reports the network problem when offline', () async {
      final result = await repository.refreshDeckWords('es-food');

      expect(result.failureOrNull, const NetworkFailure('offline'));
    });

    test('returns the stored deck while it has unsent changes', () async {
      await storeDeck('es-food', ['es-sal']);
      await repository.addWord('es-food', _pan);

      final words = (await repository.refreshDeckWords('es-food')).valueOrNull!;

      expect(words.map((w) => w.id), ['es-sal', 'new-1']);
    });

    test('reports a deck that no longer exists', () async {
      await storeDeck('es-food', ['es-sal']);
      when(() => h.wordsRemote.fetchWords(any())).thenThrow(
        const ServerException(
          'No deck.',
          statusCode: 404,
          code: 'deck_not_found',
        ),
      );

      final result = await repository.refreshDeckWords('es-food');

      expect(
        result.failureOrNull,
        isA<ServerFailure>().having((f) => f.code, 'code', 'deck_not_found'),
      );
      expect(await h.local.wordsOfDeck('es-food'), isEmpty);
    });
  });

  group('addWord', () {
    test('stores the word at once, last in the deck and due now', () async {
      await storeDeck(testDeckId, ['a', 'b']);

      final added = (await repository.addWord(testDeckId, _pan)).valueOrNull!;

      expect(added.id, 'new-1');
      expect(added.deckId, testDeckId);
      expect(added.questionShort, 'el pan');
      final stored = await h.local.wordsOfDeck(testDeckId);
      expect(stored.last.id, 'new-1');
      expect(stored.last.position, 2);
      expect(await h.local.countDue(h.now), 3);
    });

    test('queues it for the service and sends it with its id', () async {
      h.acceptChanges();

      await repository.addWord('es-food', _pan);
      await h.sync.push();

      verify(
        () => h.wordsRemote.addWords('es-food', [(id: 'new-1', draft: _pan)]),
      ).called(1);
      expect(await h.pending.count(), 0);
    });

    test('keeps it queued while offline', () async {
      final result = await repository.addWord('es-food', _pan);
      await h.sync.push();

      expect(result.isSuccess, isTrue);
      expect(await queued(), [
        const WordAdded(deckId: 'es-food', wordId: 'new-1', draft: _pan),
      ]);
    });

    test('refuses a sentence already in the deck', () async {
      await repository.addWord('es-food', _pan);

      final result = await repository.addWord('es-food', _pan);

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await h.local.wordsOfDeck('es-food'), hasLength(1));
      expect(await h.pending.count(), 1);
    });
  });

  group('editWord', () {
    const edited = WordDraft(
      questionShort: 'el pan',
      answerShort: 'bread, loaf',
      questionExample: 'Compro pan cada mañana.',
      answerExample: 'I buy bread every morning.',
    );

    test('saves the text at once and keeps the counters', () async {
      await storeDeck(testDeckId, ['es-pan']);
      await h.local.countAnswer('es-pan', correct: true);
      final word = (await repository.deckWords(testDeckId)).valueOrNull!.single;

      final saved = (await repository.editWord(word, edited)).valueOrNull!;

      expect(saved.answerShort, 'bread, loaf');
      expect(saved.showsCount, 1);
      final stored = (await h.local.wordsOfDeck(testDeckId)).single;
      expect(stored.answerShort, 'bread, loaf');
      expect(stored.successesCount, 1);
      expect(await queued(), [
        const WordEdited(deckId: testDeckId, wordId: 'es-pan', draft: edited),
      ]);
    });

    test('allows keeping its own sentence', () async {
      await storeDeck(testDeckId, ['es-pan']);
      final word = (await repository.deckWords(testDeckId)).valueOrNull!.single;

      final result = await repository.editWord(
        word,
        WordDraft(
          questionExample: word.questionExample,
          answerExample: 'changed',
        ),
      );

      expect(result.isSuccess, isTrue);
    });

    test("refuses another word's sentence", () async {
      await storeDeck(testDeckId, ['a', 'b']);
      final words = (await repository.deckWords(testDeckId)).valueOrNull!;

      final result = await repository.editWord(
        words.first,
        WordDraft(
          questionExample: words.last.questionExample,
          answerExample: 'x',
        ),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await h.pending.count(), 0);
    });
  });

  group('deleteWord', () {
    test('removes the word and its progress at once, and queues it', () async {
      await storeDeck(testDeckId, ['a', 'b']);
      final word = (await repository.deckWords(testDeckId)).valueOrNull!.first;

      final result = await repository.deleteWord(word);

      expect(result.isSuccess, isTrue);
      final left = await h.local.wordsOfDeck(testDeckId);
      expect(left.map((row) => row.id), ['b']);
      final reviews = await h.db.select(h.db.reviews).get();
      expect(reviews.map((row) => row.wordId), ['b']);
      expect(await queued(), [
        WordDeleted(deckId: testDeckId, wordId: 'a', subject: word.question),
      ]);
    });
  });

  group('saveReview', () {
    final state = ReviewState.fresh(
      'a',
      DateTime(2026, 8, 21, 10),
    ).copyWith(repetitions: 1, intervalDays: 1, timesSeen: 1, timesCorrect: 1);

    setUp(() => storeDeck(testDeckId, ['a']));

    test('stores the review and counts the answer at once', () async {
      final result = await repository.saveReview(state, correct: true);

      expect(result.valueOrNull, state);
      final card = (await h.local.dueCards(now: h.now, limit: 8)).single;
      expect(card.review.repetitions, 1);
      expect(card.word.showsCount, 1);
      expect(card.word.successesCount, 1);
    });

    test('sends the answer in the background', () async {
      h.acceptChanges();

      await repository.saveReview(state, correct: false);
      await h.sync.push();

      verify(() => h.wordsRemote.submitReview('a', correct: false)).called(1);
      expect(await h.pending.count(), 0);
    });

    test('keeps the answer queued while offline', () async {
      await repository.saveReview(state, correct: true);
      await h.sync.push();

      expect(await queued(), [
        const WordReviewed(deckId: testDeckId, wordId: 'a', correct: true),
      ]);
    });
  });

  test('dueCards maps stored rows into study cards', () async {
    await storeDeck(testDeckId, ['a']);

    final cards = (await repository.dueCards(limit: 8)).valueOrNull!;

    expect(cards.single.id, 'a');
    expect(cards.single.review.dueAt, h.now);
  });

  test('logSession and learnerStats use the stored sessions', () async {
    await storeDeck(testDeckId, ['a', 'b']);

    final streak = await repository.logSession(
      startedAt: h.now.subtract(const Duration(minutes: 4)),
      endedAt: h.now,
      reviewedCount: 8,
      correctCount: 7,
      xpEarned: 84,
    );
    final stats = (await repository.learnerStats()).valueOrNull!;

    expect(streak.valueOrNull, 1);
    expect(stats.wordCount, 2);
    expect(stats.dueCount, 2);
    expect(stats.totalXp, 84);
    expect(stats.streakDays, 1);
  });
}
