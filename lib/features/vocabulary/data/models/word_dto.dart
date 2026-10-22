/// Wire format of one word, as served by `GET /decks/:deckId/words` and
/// `POST /words/:wordId/reviews`.
///
/// ```json
/// {
///   "id": "es-atardecer",
///   "question_short": "el atardecer",
///   "answer_short": "sunset",
///   "question_example": "Caminamos por la playa al atardecer.",
///   "answer_example": "We walked along the beach at sunset.",
///   "shows_count": 0,
///   "successes_count": 0,
///   "failures_count": 0
/// }
/// ```
///
/// A `null` [questionShort] marks a sentence card.
class WordDto {
  const WordDto({
    required this.id,
    required this.questionShort,
    required this.answerShort,
    required this.questionExample,
    required this.answerExample,
    required this.showsCount,
    required this.successesCount,
    required this.failuresCount,
  });

  /// Throws a [TypeError] when a required field is missing or mistyped.
  factory WordDto.fromJson(Map<String, dynamic> json) => WordDto(
    id: json['id'] as String,
    questionShort: json['question_short'] as String?,
    answerShort: json['answer_short'] as String?,
    questionExample: json['question_example'] as String,
    answerExample: json['answer_example'] as String,
    showsCount: json['shows_count'] as int,
    successesCount: json['successes_count'] as int,
    failuresCount: json['failures_count'] as int,
  );

  final String id;
  final String? questionShort;
  final String? answerShort;
  final String questionExample;
  final String answerExample;
  final int showsCount;
  final int successesCount;
  final int failuresCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'question_short': questionShort,
    'answer_short': answerShort,
    'question_example': questionExample,
    'answer_example': answerExample,
    'shows_count': showsCount,
    'successes_count': successesCount,
    'failures_count': failuresCount,
  };
}
