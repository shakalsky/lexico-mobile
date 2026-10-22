import 'package:equatable/equatable.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_grade.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';
import 'package:lexico/features/vocabulary/domain/services/spaced_repetition_scheduler.dart';

class RecordReviewParams extends Equatable {
  const RecordReviewParams({
    required this.card,
    required this.grade,
    required this.answeredAt,
  });

  final StudyCard card;
  final ReviewGrade grade;
  final DateTime answeredAt;

  @override
  List<Object?> get props => [card, grade, answeredAt];
}

/// Runs one answer through the scheduler and stores the result.
class RecordReview implements UseCase<ReviewState, RecordReviewParams> {
  const RecordReview(this._repository, this._scheduler);

  final VocabularyRepository _repository;
  final SpacedRepetitionScheduler _scheduler;

  @override
  Future<Result<ReviewState>> call(RecordReviewParams params) {
    final next = _scheduler.schedule(
      current: params.card.review,
      grade: params.grade,
      now: params.answeredAt,
    );
    return _repository.saveReview(next, correct: params.grade.isCorrect);
  }
}
