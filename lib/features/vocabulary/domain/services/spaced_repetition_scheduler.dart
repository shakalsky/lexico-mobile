import 'dart:math' as math;

import 'package:lexico/features/vocabulary/domain/entities/review_grade.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_rules.dart';

/// An SM-2 derivative adapted to a two-way answer (knew it / review).
///
/// Pure and side-effect free: given a state, a grade and a clock reading it
/// returns the next state. Everything about *when* a word comes back lives
/// here and nowhere else.
class SpacedRepetitionScheduler {
  const SpacedRepetitionScheduler();

  ReviewState schedule({
    required ReviewState current,
    required ReviewGrade grade,
    required DateTime now,
  }) => grade.isCorrect ? _promote(current, now) : _relearn(current, now);

  ReviewState _promote(ReviewState current, DateTime now) {
    final repetitions = current.repetitions + 1;
    final easeFactor = math.min(
      ReviewState.maxEaseFactor,
      current.easeFactor + 0.1,
    );
    final intervalDays = switch (repetitions) {
      1 => 1,
      2 => 3,
      _ => math.max(1, (current.intervalDays * easeFactor).round()),
    };

    return current.copyWith(
      repetitions: repetitions,
      easeFactor: easeFactor,
      intervalDays: intervalDays,
      dueAt: now.add(Duration(days: intervalDays)),
      lastReviewedAt: now,
      timesSeen: current.timesSeen + 1,
      timesCorrect: current.timesCorrect + 1,
    );
  }

  /// A miss resets the ladder: the word returns later the same day and its
  /// ease drops so future intervals grow more cautiously.
  ReviewState _relearn(ReviewState current, DateTime now) => current.copyWith(
    repetitions: 0,
    intervalDays: 0,
    easeFactor: math.max(ReviewState.minEaseFactor, current.easeFactor - 0.2),
    dueAt: now.add(StudyRules.relearnDelay),
    lastReviewedAt: now,
    lapses: current.lapses + 1,
    timesSeen: current.timesSeen + 1,
  );
}
