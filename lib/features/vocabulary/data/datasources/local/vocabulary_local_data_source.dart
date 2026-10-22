import 'package:drift/drift.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/models/study_card_row.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';

abstract interface class VocabularyLocalDataSource {
  /// Makes [words] the whole content of [deckId]: words no longer in the list
  /// are deleted with their progress, new words get a fresh review row, and
  /// existing progress is left untouched.
  Future<void> replaceDeck(String deckId, List<WordRow> words, DateTime now);

  /// Overwrites one word's content and counters, keeping its deck, position
  /// and progress. Does nothing if the word is not stored.
  Future<void> updateWord(String id, WordsCompanion changes);

  /// The decks the learner studies. Everything below that reads words or
  /// progress only looks at these decks.
  Future<Set<String>> studiedDeckIds();

  /// Adds [deckId] to the studied decks, or removes it. Removing keeps the
  /// deck's words and progress for when it is studied again.
  Future<void> setDeckStudied(String deckId, {required bool studied});

  /// Words stored for the studied decks.
  Future<int> wordCount();

  /// Every stored word of [deckId], in deck order, studied or not.
  Future<List<WordRow>> wordsOfDeck(String deckId);

  Future<List<StudyCardRow>> dueCards({
    required DateTime now,
    required int limit,
  });

  /// Cards not yet due, the soonest first.
  Future<List<StudyCardRow>> upcomingCards({
    required DateTime now,
    required int limit,
  });

  Future<int> countDue(DateTime now);

  Future<void> saveReview(ReviewRow review);

  Future<int> countKnown();

  Future<int> countShaky();

  Future<AnswerTotalsRow> answerTotals();

  Future<int> totalXp();

  /// The `endedAt` timestamp of every logged session, newest first.
  Future<List<DateTime>> sessionDays();

  Future<void> insertSession(StudySessionsCompanion session);
}

class VocabularyLocalDataSourceImpl implements VocabularyLocalDataSource {
  const VocabularyLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  @override
  Future<void> replaceDeck(String deckId, List<WordRow> words, DateTime now) =>
      _guard(() async {
        final ids = words.map((word) => word.id).toList(growable: false);
        await _db.batch((batch) {
          batch
            ..deleteWhere(
              _db.words,
              (t) => t.deckId.equals(deckId) & t.id.isNotIn(ids),
            )
            ..insertAllOnConflictUpdate(_db.words, words)
            ..insertAll(
              _db.reviews,
              words.map(
                (word) => ReviewsCompanion.insert(
                  wordId: word.id,
                  dueAt: now,
                  easeFactor: const Value(ReviewState.defaultEaseFactor),
                ),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        });
      });

  @override
  Future<void> updateWord(String id, WordsCompanion changes) => _guard(
    () => (_db.update(_db.words)..where((t) => t.id.equals(id))).write(changes),
  );

  @override
  Future<Set<String>> studiedDeckIds() => _guard(() async {
    final rows = await _db.select(_db.studyDecks).get();
    return {for (final row in rows) row.deckId};
  });

  @override
  Future<void> setDeckStudied(String deckId, {required bool studied}) =>
      _guard(() async {
        if (studied) {
          await _db
              .into(_db.studyDecks)
              .insert(
                StudyDecksCompanion.insert(deckId: deckId),
                mode: InsertMode.insertOrIgnore,
              );
        } else {
          await (_db.delete(
            _db.studyDecks,
          )..where((t) => t.deckId.equals(deckId))).go();
        }
      });

  /// True for words that belong to a studied deck.
  Expression<bool> get _inStudiedDeck => _db.words.deckId.isInQuery(
    _db.selectOnly(_db.studyDecks)..addColumns([_db.studyDecks.deckId]),
  );

  /// Reviews joined to their words, limited to the studied decks.
  JoinedSelectStatement<HasResultSet, dynamic> _studiedReviews(
    List<Expression<Object>> columns,
    Expression<bool> where,
  ) =>
      _db.selectOnly(_db.reviews).join([
          innerJoin(
            _db.words,
            _db.words.id.equalsExp(_db.reviews.wordId),
            useColumns: false,
          ),
        ])
        ..addColumns(columns)
        ..where(where & _inStudiedDeck);

  Future<int> _countReviews(Expression<bool> where) async {
    final count = _db.reviews.wordId.count();
    final row = await _studiedReviews([count], where).getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<int> wordCount() =>
      _guard(() => _db.words.count(where: (_) => _inStudiedDeck).getSingle());

  @override
  Future<List<WordRow>> wordsOfDeck(String deckId) => _guard(
    () =>
        (_db.select(_db.words)
              ..where((t) => t.deckId.equals(deckId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get(),
  );

  @override
  Future<List<StudyCardRow>> dueCards({
    required DateTime now,
    required int limit,
  }) => _cardsWhere(_db.reviews.dueAt.isSmallerOrEqualValue(now), limit);

  @override
  Future<List<StudyCardRow>> upcomingCards({
    required DateTime now,
    required int limit,
  }) => _cardsWhere(_db.reviews.dueAt.isBiggerThanValue(now), limit);

  /// Studied cards matching [where], the earliest due first.
  Future<List<StudyCardRow>> _cardsWhere(Expression<bool> where, int limit) =>
      _guard(() async {
        final query =
            _db.select(_db.reviews).join([
                innerJoin(
                  _db.words,
                  _db.words.id.equalsExp(_db.reviews.wordId),
                ),
              ])
              ..where(where & _inStudiedDeck)
              ..orderBy([
                OrderingTerm.asc(_db.reviews.dueAt),
                OrderingTerm.asc(_db.words.position),
              ])
              ..limit(limit);

        final rows = await query.get();
        return rows
            .map(
              (row) => StudyCardRow(
                word: row.readTable(_db.words),
                review: row.readTable(_db.reviews),
              ),
            )
            .toList(growable: false);
      });

  @override
  Future<int> countDue(DateTime now) =>
      _guard(() => _countReviews(_db.reviews.dueAt.isSmallerOrEqualValue(now)));

  @override
  Future<void> saveReview(ReviewRow review) =>
      _guard(() => _db.into(_db.reviews).insertOnConflictUpdate(review));

  @override
  Future<int> countKnown() => _guard(
    () => _countReviews(
      _db.reviews.repetitions.isBiggerOrEqualValue(
        ReviewState.knownRepetitionThreshold,
      ),
    ),
  );

  @override
  Future<int> countShaky() => _guard(
    () => _countReviews(
      _db.reviews.lapses.isBiggerThanValue(0) &
          _db.reviews.repetitions.isSmallerThanValue(
            ReviewState.knownRepetitionThreshold,
          ),
    ),
  );

  @override
  Future<AnswerTotalsRow> answerTotals() => _guard(() async {
    final seen = _db.reviews.timesSeen.sum();
    final correct = _db.reviews.timesCorrect.sum();
    final row = await _studiedReviews([
      seen,
      correct,
    ], const Constant(true)).getSingle();

    return AnswerTotalsRow(
      timesSeen: row.read(seen) ?? 0,
      timesCorrect: row.read(correct) ?? 0,
    );
  });

  @override
  Future<int> totalXp() => _guard(() async {
    final xp = _db.studySessions.xpEarned.sum();
    final row = await (_db.selectOnly(
      _db.studySessions,
    )..addColumns([xp])).getSingle();
    return row.read(xp) ?? 0;
  });

  @override
  Future<List<DateTime>> sessionDays() => _guard(() async {
    final query = _db.selectOnly(_db.studySessions)
      ..addColumns([_db.studySessions.endedAt])
      ..orderBy([OrderingTerm.desc(_db.studySessions.endedAt)]);

    final rows = await query.get();
    return rows
        .map((row) => row.read(_db.studySessions.endedAt))
        .whereType<DateTime>()
        .toList(growable: false);
  });

  @override
  Future<void> insertSession(StudySessionsCompanion session) =>
      _guard(() => _db.into(_db.studySessions).insert(session));

  /// Every database error leaves this class as a [CacheException].
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on CacheException {
      rethrow;
    } catch (error) {
      throw CacheException('Local database error: $error');
    }
  }
}
