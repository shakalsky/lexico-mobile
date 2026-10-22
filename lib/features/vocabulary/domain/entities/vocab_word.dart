import 'package:equatable/equatable.dart';

/// A word as it exists in the deck, independent of how well it is known.
class VocabWord extends Equatable {
  const VocabWord({
    required this.id,
    required this.deckId,
    required this.questionShort,
    required this.answerShort,
    required this.questionExample,
    required this.answerExample,
    this.showsCount = 0,
    this.successesCount = 0,
    this.failuresCount = 0,
  });

  final String id;
  final String deckId;

  /// The word in the language being learned, e.g. `el atardecer`. `null` for
  /// a sentence card, which is studied as the whole [questionExample].
  final String? questionShort;

  /// Its meaning, e.g. `sunset`. `null` when not given.
  final String? answerShort;

  /// Example sentence in the language being learned.
  final String questionExample;

  /// [questionExample] translated.
  final String answerExample;

  /// Answer totals as counted by the word service.
  final int showsCount;
  final int successesCount;
  final int failuresCount;

  bool get isSentence => questionShort == null;

  /// What the front of the card asks.
  String get question => questionShort ?? questionExample;

  /// What the back of the card answers.
  String get answer => answerShort ?? answerExample;

  /// The example under the [question], unless it is the question itself.
  String? get questionDetail => isSentence ? null : questionExample;

  /// The example under the [answer], unless it is the answer itself.
  String? get answerDetail => answerShort == null ? null : answerExample;

  @override
  List<Object?> get props => [
    id,
    deckId,
    questionShort,
    answerShort,
    questionExample,
    answerExample,
    showsCount,
    successesCount,
    failuresCount,
  ];
}
