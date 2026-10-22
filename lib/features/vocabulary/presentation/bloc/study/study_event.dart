part of 'study_bloc.dart';

sealed class StudyEvent extends Equatable {
  const StudyEvent();

  @override
  List<Object?> get props => const [];
}

/// Deal a new stack. Also used by "another round" on the summary screen.
final class StudySessionRequested extends StudyEvent {
  const StudySessionRequested();
}

/// The learner tapped the card to see the answer, or tapped it back.
final class StudyCardFlipped extends StudyEvent {
  const StudyCardFlipped();
}

/// A swipe (or a tap on one of the two buttons) resolved the top card.
final class StudyAnswerSubmitted extends StudyEvent {
  const StudyAnswerSubmitted(this.grade);

  final ReviewGrade grade;

  @override
  List<Object?> get props => [grade];
}

final class StudyToastDismissed extends StudyEvent {
  const StudyToastDismissed();
}

/// Left through the ✕. Work already done is still logged.
final class StudySessionQuit extends StudyEvent {
  const StudySessionQuit();
}
