import 'package:drift/drift.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/local_transaction.dart';
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

  /// Stores a new word, due at once.
  Future<void> insertWord(WordRow word, DateTime now);

  /// Removes one word and its progress. Does nothing if it is not stored.
  Future<void> deleteWord(String id);

  /// The position after the last word of [deckId].
  Future<int> nextPosition(String deckId);

  /// Whether a word of [deckId] other than [exceptWordId] has this exact
  /// [questionExample]. The service refuses such duplicates.
  Future<bool> hasQuestionExample(
    String deckId,
    String questionExample, {
    String? exceptWordId,
  });

  /// The deck [wordId] belongs to, or `null` if it is not stored.
  Future<String?> deckIdOfWord(String wordId);

  /// Counts one answer in the word's counters, as the service will once it
  /// hears of it.
  Future<void> countAnswer(String wordId, {required bool correct});

  /// The decks the learner studies. Everything below that reads words or
  /// progress only looks at these decks.
  Future<Set<String>> studiedDeckIds();

  /// Adds [deckId] to the studied decks, or removes it. Removing keeps the
  /// deck's words and progress for when it is studied again.
  Future<void> setDeckStudied(String deckId, {required bool studied});

  /// Forgets [deckId] entirely: the deck, its words, their progress, and its
  /// place among the studied decks. For decks the service no longer has.
  Future<void> deleteDeck(String deckId);

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
  Future<void> insertWord(WordRow word, DateTime now) => _guard(
    () => _db.transaction(() async {
      await _db.into(_db.words).insert(word);
      await _db
          .into(_db.reviews)
          .insert(
            ReviewsCompanion.insert(
              wordId: word.id,
              dueAt: now,
              easeFactor: const Value(ReviewState.defaultEaseFactor),
            ),
          );
    }),
  );

  @override
  Future<void> deleteWord(String id) => _guard(
    // Its review goes with it (ON DELETE CASCADE).
    () => (_db.delete(_db.words)..where((t) => t.id.equals(id))).go(),
  );

  @override
  Future<int> nextPosition(String deckId) => _guard(() async {
    final last = _db.words.position.max();
    final row =
        await (_db.selectOnly(_db.words)
              ..addColumns([last])
              ..where(_db.words.deckId.equals(deckId)))
            .getSingle();
    final position = row.read(last);
    return position == null ? 0 : position + 1;
  });

  @override
  Future<bool> hasQuestionExample(
    String deckId,
    String questionExample, {
    String? exceptWordId,
  }) => _guard(() async {
    final count = await _db.words
        .count(
          where: (t) {
            final same =
                t.deckId.equals(deckId) &
                t.questionExample.equals(questionExample);
            return exceptWordId == null
                ? same
                : same & t.id.equals(exceptWordId).not();
          },
        )
        .getSingle();
    return count > 0;
  });

  @override
  Future<String?> deckIdOfWord(String wordId) => _guard(() async {
    final query = _db.selectOnly(_db.words)
      ..addColumns([_db.words.deckId])
      ..where(_db.words.id.equals(wordId));
    final row = await query.getSingleOrNull();
    return row?.read(_db.words.deckId);
  });

  @override
  Future<void> countAnswer(String wordId, {required bool correct}) => _guard(
    () => (_db.update(_db.words)..where((t) => t.id.equals(wordId))).write(
      WordsCompanion.custom(
        showsCount: _db.words.showsCount + const Constant(1),
        successesCount: correct
            ? _db.words.successesCount + const Constant(1)
            : null,
        failuresCount: correct
            ? null
            : _db.words.failuresCount + const Constant(1),
      ),
    ),
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

  @override
  Future<void> deleteDeck(String deckId) => _guard(
    () => _db.transaction(() async {
      // Reviews go with their words (ON DELETE CASCADE).
      await (_db.delete(_db.words)..where((t) => t.deckId.equals(deckId))).go();
      await (_db.delete(
        _db.studyDecks,
      )..where((t) => t.deckId.equals(deckId))).go();
      await (_db.delete(_db.decks)..where((t) => t.id.equals(deckId))).go();
    }),
  );

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

  Future<T> _guard<T>(Future<T> Function() body) => guardLocal(body);
}
