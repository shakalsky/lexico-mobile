import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_grade.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_rules.dart';
import 'package:lexico/features/vocabulary/domain/services/spaced_repetition_scheduler.dart';

void main() {
  const scheduler = SpacedRepetitionScheduler();
  final now = DateTime(2026, 8, 21, 10);

  ReviewState fresh() => ReviewState.fresh('es-atardecer', now);

  group('a correct answer', () {
    test('schedules the first repetition one day out', () {
      final next = scheduler.schedule(
        current: fresh(),
        grade: ReviewGrade.knewIt,
        now: now,
      );

      expect(next.repetitions, 1);
      expect(next.intervalDays, 1);
      expect(next.dueAt, now.add(const Duration(days: 1)));
      expect(next.timesSeen, 1);
      expect(next.timesCorrect, 1);
      expect(next.lastReviewedAt, now);
    });

    test('walks 1 → 3 → interval × ease', () {
      var state = fresh();
      for (var i = 0; i < 3; i++) {
        state = scheduler.schedule(
          current: state,
          grade: ReviewGrade.knewIt,
          now: now,
        );
      }

      expect(state.repetitions, 3);
      // Third pass multiplies the 3-day interval by the grown ease factor.
      expect(state.intervalDays, (3 * (2.5 + 0.3)).round());
      expect(state.isKnown, isTrue);
    });

    test('never pushes the ease factor past its ceiling', () {
      var state = fresh();
      for (var i = 0; i < 12; i++) {
        state = scheduler.schedule(
          current: state,
          grade: ReviewGrade.knewIt,
          now: now,
        );
      }

      expect(state.easeFactor, ReviewState.maxEaseFactor);
    });
  });

  group('a missed answer', () {
    test('resets the ladder and returns the word the same day', () {
      final known = ReviewState(
        wordId: 'es-sensible',
        repetitions: 4,
        intervalDays: 21,
        easeFactor: 2.6,
        dueAt: now,
        lapses: 0,
        timesSeen: 4,
        timesCorrect: 4,
      );

      final next = scheduler.schedule(
        current: known,
        grade: ReviewGrade.needsReview,
        now: now,
      );

      expect(next.repetitions, 0);
      expect(next.intervalDays, 0);
      expect(next.dueAt, now.add(StudyRules.relearnDelay));
      expect(next.lapses, 1);
      expect(next.easeFactor, closeTo(2.4, 1e-9));
      expect(next.timesSeen, 5);
      expect(next.timesCorrect, 4, reason: 'a miss earns no correct answer');
      expect(next.isShaky, isTrue);
    });

    test('never drops the ease factor below its floor', () {
      var state = fresh();
      for (var i = 0; i < 12; i++) {
        state = scheduler.schedule(
          current: state,
          grade: ReviewGrade.needsReview,
          now: now,
        );
      }

      expect(state.easeFactor, ReviewState.minEaseFactor);
    });
  });
}
