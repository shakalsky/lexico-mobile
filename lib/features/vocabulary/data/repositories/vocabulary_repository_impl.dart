import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/error/exception_mapper.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/network/api_config.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/utils/date_utils.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/starter_deck_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/vocabulary_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/remote/vocabulary_remote_data_source.dart';
import 'package:lexico/features/vocabulary/data/mappers/vocabulary_mappers.dart';
import 'package:lexico/features/vocabulary/data/models/study_card_row.dart';
import 'package:lexico/features/vocabulary/data/models/word_dto.dart';
import 'package:lexico/features/vocabulary/domain/entities/learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

class VocabularyRepositoryImpl implements VocabularyRepository {
  VocabularyRepositoryImpl({
    required VocabularyRemoteDataSource remote,
    required VocabularyLocalDataSource local,
    required StarterDeckDataSource starterDeck,
    String starterDeckId = ApiConfig.defaultDeckId,
    DateTime Function() clock = DateTime.now,
  }) : _remote = remote,
       _local = local,
       _starterDeck = starterDeck,
       _starterDeckId = starterDeckId,
       _clock = clock;

  final VocabularyRemoteDataSource _remote;
  final VocabularyLocalDataSource _local;
  final StarterDeckDataSource _starterDeck;

  /// The deck the bundled starter words belong to.
  final String _starterDeckId;
  final DateTime Function() _clock;

  /// Network first, deck by deck; a deck that can't be fetched keeps what is
  /// already stored. A device with nothing stored at all falls back to the
  /// bundled deck, if that deck is studied.
  @override
  Future<Result<int>> syncDecks() async {
    final now = _clock();

    try {
      for (final deckId in await _local.studiedDeckIds()) {
        await _syncDeck(deckId, now);
      }

      final stored = await _local.wordCount();
      if (stored > 0) return Result.success(stored);
      return await _seedStarterDeck(now);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  /// Refreshes one deck. Only network and server problems are swallowed;
  /// a local database error still fails the sync.
  Future<void> _syncDeck(String deckId, DateTime now) async {
    final List<WordDto> words;
    try {
      words = await _remote.fetchWords(deckId);
    } on CacheException {
      rethrow;
    } on AppException catch (error) {
      debugPrint('Léxico: kept stored words for $deckId — ${error.message}');
      return;
    }
    // An empty reply keeps what is stored rather than leaving nothing to
    // study.
    if (words.isNotEmpty) {
      await _local.replaceDeck(deckId, deckRows(deckId, words), now);
    }
  }

  Future<Result<int>> _seedStarterDeck(DateTime now) async {
    if (!(await _local.studiedDeckIds()).contains(_starterDeckId)) {
      return const Result.success(0);
    }
    final starter = await _starterDeck.load();
    await _local.replaceDeck(
      _starterDeckId,
      deckRows(_starterDeckId, starter),
      now,
    );
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

  /// Turning a deck on also fetches its words, so it can be studied at once;
  /// if that fails the next sync tries again.
  @override
  Future<Result<void>> setDeckStudied(
    String deckId, {
    required bool studied,
  }) async {
    try {
      await _local.setDeckStudied(deckId, studied: studied);
      if (studied) await _syncDeck(deckId, _clock());
      return const Result.success(null);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  @override
  Future<Result<List<VocabWord>>> deckWords(String deckId) async {
    try {
      final words = await _remote.fetchWords(deckId);
      return Result.success([
        for (final word in words) word.toEntity(deckId: deckId),
      ]);
    } on ServerException catch (error) {
      // The deck is gone; stored words of it would only mislead.
      if (error.code == 'deck_not_found') {
        return Result.failure(error.toFailure());
      }
      return _storedDeckWords(deckId, error);
    } on AppException catch (error) {
      return _storedDeckWords(deckId, error);
    }
  }

  @override
  Future<Result<VocabWord>> addWord(String deckId, WordDraft word) async {
    final List<WordDto> reply;
    try {
      reply = await _remote.addWords(deckId, [word]);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
    if (reply.length != 1) {
      return const Result.failure(
        ServerFailure('The word service did not return the new word.'),
      );
    }
    final created = reply.first;

    // The word is saved on the service either way; a failed local refresh
    // only delays it until the next sync.
    try {
      if ((await _local.studiedDeckIds()).contains(deckId)) {
        await _syncDeck(deckId, _clock());
      }
    } on AppException catch (error) {
      debugPrint('Léxico: new word not stored yet — ${error.message}');
    }
    return Result.success(created.toEntity(deckId: deckId));
  }

  @override
  Future<Result<VocabWord>> editWord(VocabWord word, WordDraft draft) async {
    final WordDto saved;
    try {
      saved = await _remote.editWord(word.id, draft);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }

    // Saved on the service either way; a failed local update is fixed by the
    // next sync. Words that aren't stored make this a no-op.
    try {
      await _local.updateWord(saved.id, saved.toContentUpdate());
    } on AppException catch (error) {
      debugPrint('Léxico: edited word not stored yet — ${error.message}');
    }
    return Result.success(saved.toEntity(deckId: word.deckId));
  }

  /// The fallback for [deckWords]: the stored copy, if there is one.
  Future<Result<List<VocabWord>>> _storedDeckWords(
    String deckId,
    AppException networkError,
  ) async {
    try {
      final rows = await _local.wordsOfDeck(deckId);
      if (rows.isEmpty) return Result.failure(networkError.toFailure());
      return Result.success([for (final row in rows) row.toEntity()]);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
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

  @override
  Future<Result<ReviewState>> saveReview(
    ReviewState state, {
    required bool correct,
  }) async {
    try {
      await _local.saveReview(state.toRow());
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
    unawaited(_reportAnswer(state.wordId, correct: correct));
    return Result.success(state);
  }

  /// Sends the answer to the word service in the background, so a slow or
  /// missing network never holds up the next card. Scheduling only depends
  /// on the local review, so a lost report costs nothing but the server's
  /// counters. The call is never retried: the API counts every request.
  Future<void> _reportAnswer(String wordId, {required bool correct}) async {
    try {
      final word = await _remote.submitReview(wordId, correct: correct);
      await _local.updateWord(word.id, word.toContentUpdate());
    } on AppException catch (error) {
      debugPrint('Léxico: answer to $wordId not reported — ${error.message}');
    }
  }

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
