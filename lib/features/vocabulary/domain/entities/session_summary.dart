import 'package:equatable/equatable.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';

/// What the learner sees once the stack is empty.
class SessionSummary extends Equatable {
  const SessionSummary({
    required this.reviewedCount,
    required this.correctCount,
    required this.xpEarned,
    required this.streakDays,
    required this.missedWords,
  });

  final int reviewedCount;
  final int correctCount;
  final int xpEarned;

  /// Streak length after this session was logged.
  final int streakDays;

  /// Words swiped left — the "back tomorrow" list.
  final List<VocabWord> missedWords;

  int get accuracyPercent =>
      reviewedCount == 0 ? 0 : ((correctCount / reviewedCount) * 100).round();

  @override
  List<Object?> get props => [
    reviewedCount,
    correctCount,
    xpEarned,
    streakDays,
    missedWords,
  ];
}
