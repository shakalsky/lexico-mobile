import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';

/// The text fields of a word as the API names them.
extension WordDraftJson on WordDraft {
  /// A `null` word or meaning is sent as `null`, which the API stores as
  /// "not given".
  Map<String, dynamic> toJson() => {
    'question_short': questionShort,
    'answer_short': answerShort,
    'question_example': questionExample,
    'answer_example': answerExample,
  };

  /// Throws a [TypeError] when a field is missing or mistyped.
  static WordDraft fromJson(Map<String, dynamic> json) => WordDraft(
    questionShort: json['question_short'] as String?,
    answerShort: json['answer_short'] as String?,
    questionExample: json['question_example'] as String,
    answerExample: json['answer_example'] as String,
  );
}
