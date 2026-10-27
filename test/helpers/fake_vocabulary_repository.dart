import 'dart:async';

import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/utils/date_utils.dart';
import 'package:lexico/features/vocabulary/domain/entities/card_level.dart';
import 'package:lexico/features/vocabulary/domain/entities/learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

/// An in-memory stand-in for the real repository, so widget and bloc tests can
/// exercise the whole feature without a database or a network.
class FakeVocabularyRepository implements VocabularyRepository {
  FakeVocabularyRepository({
    List<StudyCard> cards = const [],
    Set<String> studied = const {'es-en-core'},
    this.clock = _defaultClock,
  }) : _cards = [...cards],
       studiedIds = {...studied};

  static DateTime _defaultClock() => DateTime(2026, 8, 21, 10);

  final List<StudyCard> _cards;
  final DateTime Function() clock;

  final List<ReviewState> savedReviews = [];

  /// The `correct` flag passed with each saved review, in order.
  final List<bool> reportedAnswers = [];
  final List<DateTime> sessionDays = [];
  int loggedSessions = 0;
  int totalXp = 0;
  int syncCalls = 0;

  final Set<String> studiedIds;

  /// When set, [setDeckStudied] fails with it instead of saving.
  Failure? setStudiedFailure;

  /// The words stored per deck, which [deckWords] answers with.
  final Map<String, List<VocabWord>> storedDeckWords = {};

  /// What [refreshDeckWords] answers per deck, replayed in order; the last
  /// answer repeats. Decks not listed have no words.
  final Map<String, List<Result<List<VocabWord>>>> deckWordResults = {};

  /// Calls to [refreshDeckWords].
  int deckWordCalls = 0;

  /// What [addWord] answers, replayed in order; the last answer repeats.
  /// Empty means the word is "stored" as given, under a made-up id.
  final List<Result<VocabWord>> addWordResults = [];
  final List<({String deckId, WordDraft word})> addedWords = [];

  /// What [editWord] answers, replayed in order; the last answer repeats.
  /// Empty means the edit is "saved" as given.
  final List<Result<VocabWord>> editWordResults = [];
  final List<({VocabWord word, WordDraft draft})> editedWords = [];

  @override
  Future<Result<VocabWord>> editWord(VocabWord word, WordDraft draft) async {
    editedWords.add((word: word, draft: draft));
    if (editWordResults.isNotEmpty) {
      return editWordResults.length > 1
          ? editWordResults.removeAt(0)
          : editWordResults.single;
    }
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

  /// When set, [deleteWord] fails with it instead of deleting.
  Failure? deleteWordFailure;
  final List<VocabWord> deletedWords = [];

  @override
  Future<Result<void>> deleteWord(VocabWord word) async {
    final failure = deleteWordFailure;
    if (failure != null) return Result.failure(failure);
    deletedWords.add(word);
    if (storedDeckWords[word.deckId] case final words?) {
      storedDeckWords[word.deckId] = [
        for (final w in words)
          if (w.id != word.id) w,
      ];
    }
    return const Result.success(null);
  }

  @override
  Future<Result<VocabWord>> addWord(String deckId, WordDraft word) async {
    addedWords.add((deckId: deckId, word: word));
    if (addWordResults.isNotEmpty) {
      return addWordResults.length > 1
          ? addWordResults.removeAt(0)
          : addWordResults.single;
    }
    return Result.success(
      VocabWord(
        id: 'new-${addedWords.length}',
        deckId: deckId,
        questionShort: word.questionShort,
        answerShort: word.answerShort,
        questionExample: word.questionExample,
        answerExample: word.answerExample,
      ),
    );
  }

  @override
  Future<Result<List<VocabWord>>> deckWords(String deckId) async =>
      Result.success([...?storedDeckWords[deckId]]);

  @override
  Future<Result<List<VocabWord>>> refreshDeckWords(String deckId) async {
    deckWordCalls++;
    final results = deckWordResults[deckId];
    if (results == null) return const Result.success([]);
    final result = results.length > 1 ? results.removeAt(0) : results.single;
    if (result case Success(:final value)) storedDeckWords[deckId] = value;
    return result;
  }

  @override
  Future<Result<int>> syncDecks() async {
    syncCalls++;
    return Result.success(_cards.length);
  }

  @override
  Future<Result<Set<String>>> studiedDeckIds() async =>
      Result.success({...studiedIds});

  @override
  Future<Result<void>> setDeckStudied(
    String deckId, {
    required bool studied,
  }) async {
    final failure = setStudiedFailure;
    if (failure != null) return Result.failure(failure);
    studied ? studiedIds.add(deckId) : studiedIds.remove(deckId);
    return const Result.success(null);
  }

  @override
  Future<Result<List<StudyCard>>> dueCards({required int limit}) async {
    final now = clock();
    final due = _cards
        .where((card) => card.review.isDue(now))
        .take(limit)
        .toList(growable: false);
    return Result.success(due);
  }

  @override
  Future<Result<List<StudyCard>>> upcomingCards({required int limit}) async {
    final now = clock();
    final upcoming = _cards.where((card) => !card.review.isDue(now)).toList()
      ..sort((a, b) => a.review.dueAt.compareTo(b.review.dueAt));
    return Result.success(upcoming.take(limit).toList(growable: false));
  }

  @override
  Future<Result<ReviewState>> saveReview(
    ReviewState state, {
    required bool correct,
  }) async {
    savedReviews.add(state);
    reportedAnswers.add(correct);
    final index = _cards.indexWhere((card) => card.id == state.wordId);
    if (index != -1) {
      _cards[index] = StudyCard(word: _cards[index].word, review: state);
    }
    return Result.success(state);
  }

  /// Whatever is added here reaches [syncConflicts].
  final StreamController<SyncConflict> conflicts = StreamController.broadcast();

  @override
  Stream<SyncConflict> syncConflicts() => conflicts.stream;

  @override
  Future<Result<LearnerStats>> learnerStats() async {
    final now = clock();
    final reviews = _cards.map((card) => card.review);
    final seen = reviews.fold(0, (sum, r) => sum + r.timesSeen);
    final correct = reviews.fold(0, (sum, r) => sum + r.timesCorrect);

    return Result.success(
      LearnerStats(
        dueCount: reviews.where((r) => r.isDue(now)).length,
        wordCount: _cards.length,
        knownCount: reviews.where((r) => r.isKnown).length,
        shakyCount: reviews.where((r) => r.isShaky).length,
        accuracyPercent: seen == 0 ? 0 : ((correct / seen) * 100).round(),
        streakDays: streakFromDays(sessionDays, now),
        totalXp: totalXp,
      ),
    );
  }

  @override
  Future<Result<int>> logSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int reviewedCount,
    required int correctCount,
    required int xpEarned,
  }) async {
    loggedSessions++;
    totalXp += xpEarned;
    sessionDays.add(endedAt);
    return Result.success(streakFromDays(sessionDays, endedAt));
  }

  /// Convenience for assertions that care about the XP rule, for new cards.
  static int xpFor(int correctAnswers) =>
      correctAnswers * CardLevel.a0.xpPerCorrectAnswer;
}
