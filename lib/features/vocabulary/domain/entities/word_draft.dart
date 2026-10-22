import 'package:equatable/equatable.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';

/// The text of a word as the learner is writing it, for a new word or an
/// edit. The service owns the id, the deck and the counters.
class WordDraft extends Equatable {
  const WordDraft({
    required this.questionExample,
    required this.answerExample,
    this.questionShort,
    this.answerShort,
  });

  /// The text [word] has now, to start an edit from.
  factory WordDraft.of(VocabWord word) => WordDraft(
    questionShort: word.questionShort,
    answerShort: word.answerShort,
    questionExample: word.questionExample,
    answerExample: word.answerExample,
  );

  /// The word itself, e.g. `el pan`. `null` makes it a sentence card.
  final String? questionShort;

  /// Its meaning, e.g. `bread`.
  final String? answerShort;

  /// Example sentence in the language being learned.
  final String questionExample;

  /// [questionExample] translated.
  final String answerExample;

  /// Trimmed, with an empty word or meaning turned into "not given".
  WordDraft normalized() => WordDraft(
    questionShort: _optional(questionShort),
    answerShort: _optional(answerShort),
    questionExample: questionExample.trim(),
    answerExample: answerExample.trim(),
  );

  static String? _optional(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [
    questionShort,
    answerShort,
    questionExample,
    answerExample,
  ];
}
