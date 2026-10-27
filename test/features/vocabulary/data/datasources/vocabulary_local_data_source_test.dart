import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/vocabulary_local_data_source.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  late AppDatabase db;
  late VocabularyLocalDataSourceImpl local;

  final now = DateTime(2026, 8, 21, 10);

  WordRow row(String id, {int position = 0}) => WordRow(
    id: id,
    deckId: testDeckId,
    position: position,
    questionShort: 'término $id',
    answerShort: 'word $id',
    questionExample: 'ejemplo $id',
    answerExample: 'example $id',
    showsCount: 0,
    successesCount: 0,
    failuresCount: 0,
  );

  Future<void> replace(List<WordRow> rows, [DateTime? at]) =>
      local.replaceDeck(testDeckId, rows, at ?? now);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = VocabularyLocalDataSourceImpl(db);
  });

  tearDown(() => db.close());

  test('inserting words makes them immediately due', () async {
    await replace([row('a'), row('b', position: 1)]);

    expect(await local.wordCount(), 2);
    expect(await local.countDue(now), 2);

    final cards = await local.dueCards(now: now, limit: 8);
    expect(cards.map((card) => card.word.id), ['a', 'b']);
    expect(cards.first.review.easeFactor, ReviewState.defaultEaseFactor);
  });

  test('upcoming cards are the ones not due yet, soonest first', () async {
    await replace([row('a'), row('b', position: 1), row('c', position: 2)]);
    for (final (id, days) in [('a', 5), ('b', 2)]) {
      await local.saveReview(
        ReviewState.fresh(
          id,
          now,
        ).copyWith(dueAt: now.add(Duration(days: days))).toTestRow(),
      );
    }

    final upcoming = await local.upcomingCards(now: now, limit: 8);

    expect(upcoming.map((card) => card.word.id), ['b', 'a']);
  });

  test('re-syncing refreshes content without resetting progress', () async {
    await replace([row('a')]);

    final answered = ReviewState.fresh('a', now).copyWith(
      repetitions: 3,
      intervalDays: 8,
      dueAt: now.add(const Duration(days: 8)),
      timesSeen: 3,
      timesCorrect: 3,
    );
    await local.saveReview(answered.toTestRow());

    // The service changed the answer.
    await replace([
      row('a').copyWith(answerShort: const Value('updated')),
    ], now.add(const Duration(days: 1)));

    expect(await local.countKnown(), 1);
    expect(await local.countDue(now), 0, reason: 'still scheduled for later');

    final future = await local.dueCards(
      now: now.add(const Duration(days: 9)),
      limit: 8,
    );
    expect(future.single.word.answerShort, 'updated');
    expect(future.single.review.repetitions, 3);
  });

  test('re-syncing drops words the service no longer has', () async {
    await replace([row('a'), row('b', position: 1)]);
    await local.saveReview(
      ReviewState.fresh('b', now).copyWith(repetitions: 4).toTestRow(),
    );

    await replace([row('a')]);

    expect(await local.wordCount(), 1);
    expect(await local.countKnown(), 0, reason: "b's progress went with it");
  });

  test('replacing one deck leaves other decks alone', () async {
    await local.setDeckStudied('other-deck', studied: true);
    await replace([row('a')]);
    await local.replaceDeck('other-deck', [
      row('x').copyWith(deckId: 'other-deck'),
    ], now);

    await replace([row('a'), row('b', position: 1)]);

    expect(await local.wordCount(), 3);
  });

  test("lists a deck's words in order, studied or not", () async {
    await local.replaceDeck('other-deck', [
      row('y', position: 1).copyWith(deckId: 'other-deck'),
      row('x').copyWith(deckId: 'other-deck'),
    ], now);
    await replace([row('a')]);

    final words = await local.wordsOfDeck('other-deck');

    expect(words.map((w) => w.id), ['x', 'y']);
    expect(await local.wordsOfDeck('missing'), isEmpty);
  });

  group('studied decks', () {
    Future<void> storeOtherDeck() => local.replaceDeck('other-deck', [
      row('x').copyWith(deckId: 'other-deck'),
      row('y', position: 1).copyWith(deckId: 'other-deck'),
    ], now);

    test('a new database studies the core deck', () async {
      expect(await local.studiedDeckIds(), {testDeckId});
    });

    test('words of decks not studied are left out of everything', () async {
      await replace([row('a')]);
      await storeOtherDeck();
      await local.saveReview(
        ReviewState.fresh(
          'x',
          now,
        ).copyWith(repetitions: 4, timesSeen: 5, timesCorrect: 4).toTestRow(),
      );

      expect(await local.wordCount(), 1);
      expect(await local.countDue(now), 1);
      expect(await local.countKnown(), 0);
      expect((await local.answerTotals()).timesSeen, 0);
      final due = await local.dueCards(now: now, limit: 8);
      expect(due.map((card) => card.word.id), ['a']);
    });

    test('studying a deck brings its words and progress back', () async {
      await replace([row('a')]);
      await storeOtherDeck();
      await local.saveReview(
        ReviewState.fresh('x', now).copyWith(repetitions: 4).toTestRow(),
      );

      await local.setDeckStudied('other-deck', studied: true);

      expect(await local.studiedDeckIds(), {testDeckId, 'other-deck'});
      expect(await local.wordCount(), 3);
      expect(await local.countKnown(), 1);
    });

    test('dropping a deck keeps its progress for later', () async {
      await replace([row('a')]);
      await local.saveReview(
        ReviewState.fresh('a', now).copyWith(repetitions: 4).toTestRow(),
      );

      await local.setDeckStudied(testDeckId, studied: false);
      expect(await local.studiedDeckIds(), isEmpty);
      expect(await local.wordCount(), 0);

      await local.setDeckStudied(testDeckId, studied: true);
      expect(await local.countKnown(), 1);
    });

    test('studying a deck twice is harmless', () async {
      await local.setDeckStudied(testDeckId, studied: true);

      expect(await local.studiedDeckIds(), {testDeckId});
    });
  });

  test(
    'deleting a deck drops it, its words, progress and study flag',
    () async {
      await db
          .into(db.decks)
          .insert(
            DeckRow(
              id: testDeckId,
              name: 'Core',
              language: 'Español',
              createdAt: now,
            ),
          );
      await replace([row('a'), row('b', position: 1)]);
      await local.saveReview(ReviewState.fresh('a', now).toTestRow());
      await local.replaceDeck('es-food', [
        row('pan').copyWith(deckId: 'es-food'),
      ], now);
      await local.setDeckStudied('es-food', studied: true);

      await local.deleteDeck(testDeckId);

      expect(await local.wordsOfDeck(testDeckId), isEmpty);
      expect(await local.studiedDeckIds(), {'es-food'});
      expect(await db.select(db.reviews).get(), hasLength(1));
      expect(await local.wordCount(), 1);
      expect(await db.select(db.decks).get(), isEmpty);
    },
  );

  group('words added on the device', () {
    test('are stored due at once, after the last word', () async {
      await replace([row('a'), row('b', position: 1)]);

      final position = await local.nextPosition(testDeckId);
      await local.insertWord(row('c', position: position), now);

      expect(position, 2);
      final cards = await local.dueCards(now: now, limit: 8);
      expect(cards.map((card) => card.word.id), ['a', 'b', 'c']);
    });

    test('start a new deck at position zero', () async {
      expect(await local.nextPosition('es-food'), 0);
    });
  });

  test(
    'finds a sentence already in the deck, but not the word itself',
    () async {
      await replace([row('a')]);

      expect(await local.hasQuestionExample(testDeckId, 'ejemplo a'), isTrue);
      expect(await local.hasQuestionExample('es-food', 'ejemplo a'), isFalse);
      expect(
        await local.hasQuestionExample(
          testDeckId,
          'ejemplo a',
          exceptWordId: 'a',
        ),
        isFalse,
      );
    },
  );

  test('knows which deck a word belongs to', () async {
    await replace([row('a')]);

    expect(await local.deckIdOfWord('a'), testDeckId);
    expect(await local.deckIdOfWord('missing'), isNull);
  });

  test('counts an answer in the word counters', () async {
    await replace([row('a')]);

    await local.countAnswer('a', correct: true);
    await local.countAnswer('a', correct: false);

    final word = (await local.wordsOfDeck(testDeckId)).single;
    expect(word.showsCount, 2);
    expect(word.successesCount, 1);
    expect(word.failuresCount, 1);
  });

  test('cards due at the same moment keep the deck order', () async {
    await replace(
      [
        row('first'),
        row('second', position: 1),
        row('third', position: 2),
      ].reversed.toList(),
    );

    final cards = await local.dueCards(now: now, limit: 8);

    expect(cards.map((card) => card.word.id), ['first', 'second', 'third']);
  });

  test('updating a word refreshes its counters but not its place', () async {
    await replace([row('a', position: 5)]);

    await local.updateWord(
      'a',
      const WordsCompanion(
        showsCount: Value(3),
        successesCount: Value(2),
        failuresCount: Value(1),
      ),
    );

    final word = (await local.dueCards(now: now, limit: 1)).single.word;
    expect(word.showsCount, 3);
    expect(word.successesCount, 2);
    expect(word.failuresCount, 1);
    expect(word.position, 5);
    expect(word.deckId, testDeckId);
  });

  test('due cards come back oldest first and respect the limit', () async {
    await replace([row('a'), row('b', position: 1), row('c', position: 2)]);
    await local.saveReview(
      ReviewState.fresh(
        'a',
        now,
      ).copyWith(dueAt: now.subtract(const Duration(days: 2))).toTestRow(),
    );

    final cards = await local.dueCards(now: now, limit: 2);

    expect(cards, hasLength(2));
    expect(cards.first.word.id, 'a');
  });

  test('counts separate known words from shaky ones', () async {
    await replace([row('a'), row('b', position: 1), row('c', position: 2)]);
    await local.saveReview(
      ReviewState.fresh('a', now).copyWith(repetitions: 4).toTestRow(),
    );
    await local.saveReview(
      ReviewState.fresh(
        'b',
        now,
      ).copyWith(repetitions: 1, lapses: 2).toTestRow(),
    );

    expect(await local.countKnown(), 1);
    expect(await local.countShaky(), 1);
  });

  test('answer totals add up across every word', () async {
    await replace([row('a'), row('b', position: 1)]);
    await local.saveReview(
      ReviewState.fresh(
        'a',
        now,
      ).copyWith(timesSeen: 10, timesCorrect: 9).toTestRow(),
    );
    await local.saveReview(
      ReviewState.fresh(
        'b',
        now,
      ).copyWith(timesSeen: 4, timesCorrect: 3).toTestRow(),
    );

    final totals = await local.answerTotals();

    expect(totals.timesSeen, 14);
    expect(totals.timesCorrect, 12);
  });

  test('sessions accumulate XP and report their days newest first', () async {
    expect(await local.totalXp(), 0);
    expect(await local.sessionDays(), isEmpty);

    await local.insertSession(
      StudySessionsCompanion.insert(
        startedAt: now.subtract(const Duration(days: 1, minutes: 5)),
        endedAt: now.subtract(const Duration(days: 1)),
        reviewedCount: 8,
        correctCount: 6,
        xpEarned: 72,
      ),
    );
    await local.insertSession(
      StudySessionsCompanion.insert(
        startedAt: now.subtract(const Duration(minutes: 5)),
        endedAt: now,
        reviewedCount: 8,
        correctCount: 8,
        xpEarned: 96,
      ),
    );

    expect(await local.totalXp(), 168);
    expect(await local.sessionDays(), [
      now,
      now.subtract(const Duration(days: 1)),
    ]);
  });
}

extension on ReviewState {
  /// Local mirror of the production mapper, kept here so the test exercises
  /// the data source rather than importing presentation-side helpers.
  ReviewRow toTestRow() => ReviewRow(
    wordId: wordId,
    repetitions: repetitions,
    intervalDays: intervalDays,
    easeFactor: easeFactor,
    dueAt: dueAt,
    lastReviewedAt: lastReviewedAt,
    lapses: lapses,
    timesSeen: timesSeen,
    timesCorrect: timesCorrect,
  );
}
