import 'package:flutter/foundation.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/error/exception_mapper.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/network/api_config.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/utils/date_utils.dart';
import 'package:lexico/core/utils/id_generator.dart';
import 'package:lexico/features/decks/data/datasources/decks_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/local_transaction.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/pending_changes_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/starter_deck_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/vocabulary_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/mappers/vocabulary_mappers.dart';
import 'package:lexico/features/vocabulary/data/models/pending_change.dart';
import 'package:lexico/features/vocabulary/data/models/study_card_row.dart';
import 'package:lexico/features/vocabulary/data/sync/sync_engine.dart';
import 'package:lexico/features/vocabulary/domain/entities/learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

/// Offline first: reads and writes only touch the device. A write stores
/// the change and queues it in one transaction, then asks [SyncEngine] to
/// send it in the background.
class VocabularyRepositoryImpl implements VocabularyRepository {
  VocabularyRepositoryImpl({
    required VocabularyLocalDataSource local,
    required DecksLocalDataSource decksLocal,
    required PendingChangesLocalDataSource pending,
    required LocalTransaction transaction,
    required SyncEngine sync,
    required StarterDeckDataSource starterDeck,
    String starterDeckId = ApiConfig.defaultDeckId,
    DateTime Function() clock = DateTime.now,
    IdGenerator newId = uuidV4,
  }) : _local = local,
       _decksLocal = decksLocal,
       _pending = pending,
       _transaction = transaction,
       _sync = sync,
       _starterDeck = starterDeck,
       _starterDeckId = starterDeckId,
       _clock = clock,
       _newId = newId;

  final VocabularyLocalDataSource _local;
  final DecksLocalDataSource _decksLocal;
  final PendingChangesLocalDataSource _pending;
  final LocalTransaction _transaction;
  final SyncEngine _sync;
  final StarterDeckDataSource _starterDeck;

  /// The deck the bundled starter words belong to.
  final String _starterDeckId;
  final DateTime Function() _clock;
  final IdGenerator _newId;

  static const _duplicateExample = ValidationFailure(
    'This example sentence is already in the deck.',
  );

  @override
  Future<Result<int>> syncDecks() async {
    try {
      await _sync.refreshStudiedDecks();

      final stored = await _local.wordCount();
      if (stored > 0) return Result.success(stored);
      return await _seedStarterDeck(_clock());
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  Future<Result<int>> _seedStarterDeck(DateTime now) async {
    if (!(await _local.studiedDeckIds()).contains(_starterDeckId)) {
      return const Result.success(0);
    }
    final starter = await _starterDeck.load();
    await _transaction(() async {
      await _decksLocal.addDeck(
        DeckRow(
          id: _starterDeckId,
          name: starter.name,
          language: starter.language,
          createdAt: now,
        ),
      );
      await _local.replaceDeck(
        _starterDeckId,
        deckRows(_starterDeckId, starter.words),
        now,
      );
    });
    return Result.success(await _local.wordCount());
  }

  @override
  Future<Result<Set<String>>> studiedDeckIds() async {
    try {
      return Result.success(await _local.studiedDeckIds());
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  /// Turning a deck on also tries to fetch its words, so it can be studied
  /// at once; if that fails the next sync tries again.
  @override
  Future<Result<void>> setDeckStudied(
    String deckId, {
    required bool studied,
  }) async {
    try {
      await _local.setDeckStudied(deckId, studied: studied);
      if (studied) await _refreshQuietly(deckId);
      return const Result.success(null);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  /// Refreshes [deckId] if the service can be reached. Only a local database
  /// error is thrown.
  Future<void> _refreshQuietly(String deckId) async {
    try {
      await _sync.refreshDeck(deckId);
    } on CacheException {
      rethrow;
    } on AppException catch (error) {
      debugPrint('Léxico: kept stored words for $deckId — ${error.message}');
    }
  }

  @override
  Future<Result<List<VocabWord>>> deckWords(String deckId) async {
    try {
      final rows = await _local.wordsOfDeck(deckId);
      return Result.success([for (final row in rows) row.toEntity()]);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  @override
  Future<Result<List<VocabWord>>> refreshDeckWords(String deckId) async {
    try {
      await _sync.refreshDeck(deckId);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
    return deckWords(deckId);
  }

  @override
  Future<Result<VocabWord>> addWord(String deckId, WordDraft word) async {
    final now = _clock();
    final WordRow? added;
    try {
      added = await _transaction(() async {
        if (await _local.hasQuestionExample(deckId, word.questionExample)) {
          return null;
        }
        final row = WordRow(
          id: _newId(),
          deckId: deckId,
          position: await _local.nextPosition(deckId),
          questionShort: word.questionShort,
          answerShort: word.answerShort,
          questionExample: word.questionExample,
          answerExample: word.answerExample,
          showsCount: 0,
          successesCount: 0,
          failuresCount: 0,
        );
        await _local.insertWord(row, now);
        await _pending.add(
          WordAdded(deckId: deckId, wordId: row.id, draft: word),
          now,
        );
        return row;
      });
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
    if (added == null) return const Result.failure(_duplicateExample);

    _sync.schedulePush();
    return Result.success(added.toEntity());
  }

  @override
  Future<Result<VocabWord>> editWord(VocabWord word, WordDraft draft) async {
    try {
      final duplicate = await _transaction(() async {
        if (await _local.hasQuestionExample(
          word.deckId,
          draft.questionExample,
          exceptWordId: word.id,
        )) {
          return true;
        }
        await _local.updateWord(word.id, draft.toTextUpdate());
        await _pending.add(
          WordEdited(deckId: word.deckId, wordId: word.id, draft: draft),
          _clock(),
        );
        return false;
      });
      if (duplicate) return const Result.failure(_duplicateExample);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }

    _sync.schedulePush();
    return Result.success(
      VocabWord(
        id: word.id,
        deckId: word.deckId,
        questionShort: draft.questionShort,
        answerShort: draft.answerShort,
        questionExample: draft.questionExample,
        answerExample: draft.answerExample,
        showsCount: word.showsCount,
        successesCount: word.successesCount,
        failuresCount: word.failuresCount,
      ),
    );
  }

  @override
  Future<Result<void>> deleteWord(VocabWord word) async {
    try {
      await _transaction(() async {
        await _local.deleteWord(word.id);
        await _pending.add(
          WordDeleted(
            deckId: word.deckId,
            wordId: word.id,
            subject: word.question,
          ),
          _clock(),
        );
      });
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }

    _sync.schedulePush();
    return const Result.success(null);
  }

  @override
  Future<Result<List<StudyCard>>> dueCards({required int limit}) =>
      _cards(() => _local.dueCards(now: _clock(), limit: limit));

  @override
  Future<Result<List<StudyCard>>> upcomingCards({required int limit}) =>
      _cards(() => _local.upcomingCards(now: _clock(), limit: limit));

  Future<Result<List<StudyCard>>> _cards(
    Future<List<StudyCardRow>> Function() load,
  ) async {
    try {
      final rows = await load();
      return Result.success(
        rows.map((row) => row.toEntity()).toList(growable: false),
      );
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  /// Scheduling only depends on the local review, so a slow or missing
  /// network never holds up the next card. The answer is counted on the
  /// device at once and sent to the service with the next sync.
  @override
  Future<Result<ReviewState>> saveReview(
    ReviewState state, {
    required bool correct,
  }) async {
    try {
      await _transaction(() async {
        await _local.saveReview(state.toRow());
        final deckId = await _local.deckIdOfWord(state.wordId);
        if (deckId == null) return;
        await _local.countAnswer(state.wordId, correct: correct);
        await _pending.add(
          WordReviewed(deckId: deckId, wordId: state.wordId, correct: correct),
          _clock(),
        );
      });
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
    _sync.schedulePush();
    return Result.success(state);
  }

  @override
  Stream<SyncConflict> syncConflicts() => _sync.conflicts;

  @override
  Future<Result<LearnerStats>> learnerStats() async {
    try {
      final now = _clock();
      final due = await _local.countDue(now);
      final words = await _local.wordCount();
      final known = await _local.countKnown();
      final shaky = await _local.countShaky();
      final totals = await _local.answerTotals();
      final xp = await _local.totalXp();
      final days = await _local.sessionDays();

      return Result.success(
        LearnerStats(
          dueCount: due,
          wordCount: words,
          knownCount: known,
          shakyCount: shaky,
          accuracyPercent: totals.timesSeen == 0
              ? 0
              : ((totals.timesCorrect / totals.timesSeen) * 100).round(),
          streakDays: streakFromDays(days, now),
          totalXp: xp,
        ),
      );
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  @override
  Future<Result<int>> logSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int reviewedCount,
    required int correctCount,
    required int xpEarned,
  }) async {
    try {
      await _local.insertSession(
        sessionCompanion(
          startedAt: startedAt,
          endedAt: endedAt,
          reviewedCount: reviewedCount,
          correctCount: correctCount,
          xpEarned: xpEarned,
        ),
      );
      final days = await _local.sessionDays();
      return Result.success(streakFromDays(days, endedAt));
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }
}
