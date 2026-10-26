import 'package:drift/drift.dart' show Value;
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/models/study_card_row.dart';
import 'package:lexico/features/vocabulary/data/models/word_dto.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';

/// The single place where wire, database and domain shapes meet.
extension WordDtoMapper on WordDto {
  WordRow toRow({required String deckId, required int position}) => WordRow(
    id: id,
    deckId: deckId,
    position: position,
    questionShort: questionShort,
    answerShort: answerShort,
    questionExample: questionExample,
    answerExample: answerExample,
    showsCount: showsCount,
    successesCount: successesCount,
    failuresCount: failuresCount,
  );

  VocabWord toEntity({required String deckId}) => VocabWord(
    id: id,
    deckId: deckId,
    questionShort: questionShort,
    answerShort: answerShort,
    questionExample: questionExample,
    answerExample: answerExample,
    showsCount: showsCount,
    successesCount: successesCount,
    failuresCount: failuresCount,
  );

  /// Everything the service owns, for refreshing a stored word in place.
  WordsCompanion toContentUpdate() => WordsCompanion(
    questionShort: Value(questionShort),
    answerShort: Value(answerShort),
    questionExample: Value(questionExample),
    answerExample: Value(answerExample),
    showsCount: Value(showsCount),
    successesCount: Value(successesCount),
    failuresCount: Value(failuresCount),
  );
}

/// Rows for a whole deck, numbered in the order the service returned them.
List<WordRow> deckRows(String deckId, List<WordDto> words) => [
  for (final (index, word) in words.indexed)
    word.toRow(deckId: deckId, position: index),
];

extension WordDraftMapper on WordDraft {
  /// The text fields only: the word keeps its counters and place.
  WordsCompanion toTextUpdate() => WordsCompanion(
    questionShort: Value(questionShort),
    answerShort: Value(answerShort),
    questionExample: Value(questionExample),
    answerExample: Value(answerExample),
  );
}

extension WordRowMapper on WordRow {
  VocabWord toEntity() => VocabWord(
    id: id,
    deckId: deckId,
    questionShort: questionShort,
    answerShort: answerShort,
    questionExample: questionExample,
    answerExample: answerExample,
    showsCount: showsCount,
    successesCount: successesCount,
    failuresCount: failuresCount,
  );
}

extension ReviewRowMapper on ReviewRow {
  ReviewState toEntity() => ReviewState(
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

extension ReviewStateMapper on ReviewState {
  ReviewRow toRow() => ReviewRow(
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

extension StudyCardRowMapper on StudyCardRow {
  StudyCard toEntity() =>
      StudyCard(word: word.toEntity(), review: review.toEntity());
}

/// Builds the row for a finished sitting.
StudySessionsCompanion sessionCompanion({
  required DateTime startedAt,
  required DateTime endedAt,
  required int reviewedCount,
  required int correctCount,
  required int xpEarned,
}) => StudySessionsCompanion.insert(
  startedAt: startedAt,
  endedAt: endedAt,
  reviewedCount: reviewedCount,
  correctCount: correctCount,
  xpEarned: xpEarned,
);
