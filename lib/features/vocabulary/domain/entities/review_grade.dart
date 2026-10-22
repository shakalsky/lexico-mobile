/// The only two answers a swipe can produce.
enum ReviewGrade {
  /// Swiped right — the learner recalled the word.
  knewIt,

  /// Swiped left — put it back in the rotation.
  needsReview;

  bool get isCorrect => this == ReviewGrade.knewIt;
}
