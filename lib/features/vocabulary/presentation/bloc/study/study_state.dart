part of 'study_bloc.dart';

enum StudyStatus {
  initial,
  loading,

  /// A stack is on screen waiting for answers.
  studying,

  /// The stack is empty and the summary is ready.
  finished,

  /// The learner left early; the host page should pop.
  abandoned,
  failure,
}

/// The short confirmation that slides up after each answer.
class StudyToast extends Equatable {
  const StudyToast({required this.message, required this.isPositive});

  final String message;
  final bool isPositive;

  @override
  List<Object?> get props => [message, isPositive];
}

class StudyState extends Equatable {
  const StudyState({
    this.status = StudyStatus.initial,
    this.cards = const [],
    this.index = 0,
    this.isRevealed = false,
    this.outcomes = const [],
    this.summary,
    this.toast,
    this.message,
    this.startedAt,
    this.repeatMissedWords = false,
    this.showMissPictures = true,
  });

  final StudyStatus status;
  final List<StudyCard> cards;

  /// Position of the top card within [cards].
  final int index;
  final bool isRevealed;
  final List<ReviewOutcome> outcomes;
  final SessionSummary? summary;
  final StudyToast? toast;
  final String? message;
  final DateTime? startedAt;

  /// Missed cards go back to the end of [cards] until answered correctly.
  /// Read once when the session starts.
  final bool repeatMissedWords;

  /// A wrong answer pops up a random picture. Read once when the session
  /// starts.
  final bool showMissPictures;

  StudyCard? get currentCard => index < cards.length ? cards[index] : null;

  /// The top card plus the two peeking behind it.
  List<StudyCard> get visibleCards =>
      cards.skip(index).take(3).toList(growable: false);

  /// Distinct words in the session. A missed word dealt again at the end
  /// of the stack doesn't add to it.
  int get total => cards.map((c) => c.id).toSet().length;

  /// Words that are behind the learner for good: answered and not waiting
  /// to be dealt again. A miss that goes back to the end isn't done yet.
  int get completed {
    final upcoming = cards.skip(index).map((c) => c.id).toSet();
    return cards
        .take(index)
        .map((c) => c.id)
        .where((id) => !upcoming.contains(id))
        .toSet()
        .length;
  }

  int get position => completed < total ? completed + 1 : total;

  double get progress => total == 0 ? 0 : completed / total;

  StudyState copyWith({
    StudyStatus? status,
    List<StudyCard>? cards,
    int? index,
    bool? isRevealed,
    List<ReviewOutcome>? outcomes,
    SessionSummary? summary,
    StudyToast? toast,
    bool clearToast = false,
    String? message,
    DateTime? startedAt,
  }) => StudyState(
    status: status ?? this.status,
    cards: cards ?? this.cards,
    index: index ?? this.index,
    isRevealed: isRevealed ?? this.isRevealed,
    outcomes: outcomes ?? this.outcomes,
    summary: summary ?? this.summary,
    toast: clearToast ? null : (toast ?? this.toast),
    message: message,
    startedAt: startedAt ?? this.startedAt,
    repeatMissedWords: repeatMissedWords,
    showMissPictures: showMissPictures,
  );

  @override
  List<Object?> get props => [
    status,
    cards,
    index,
    isRevealed,
    outcomes,
    summary,
    toast,
    message,
    startedAt,
    repeatMissedWords,
    showMissPictures,
  ];
}
