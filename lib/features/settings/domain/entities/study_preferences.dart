import 'package:equatable/equatable.dart';

/// How the learner wants a study session to behave.
class StudyPreferences extends Equatable {
  const StudyPreferences({
    this.repeatMissedWords = false,
    this.wordsPerSession = defaultWordsPerSession,
    this.showMissPictures = true,
  });

  static const int defaultWordsPerSession = 8;
  static const int minWordsPerSession = 1;
  static const int maxWordsPerSession = 100;

  /// The quick picks offered on the settings screen.
  static const List<int> wordsPerSessionPresets = [5, 10, 15, 20];

  static bool isValidWordsPerSession(int count) =>
      count >= minWordsPerSession && count <= maxWordsPerSession;

  /// A word marked "review" goes back to the end of the session until it is
  /// answered correctly.
  final bool repeatMissedWords;

  /// How many cards one study session deals at most.
  final int wordsPerSession;

  /// A random picture pops up after a wrong answer.
  final bool showMissPictures;

  StudyPreferences copyWith({
    bool? repeatMissedWords,
    int? wordsPerSession,
    bool? showMissPictures,
  }) => StudyPreferences(
    repeatMissedWords: repeatMissedWords ?? this.repeatMissedWords,
    wordsPerSession: wordsPerSession ?? this.wordsPerSession,
    showMissPictures: showMissPictures ?? this.showMissPictures,
  );

  @override
  List<Object?> get props => [
    repeatMissedWords,
    wordsPerSession,
    showMissPictures,
  ];
}
