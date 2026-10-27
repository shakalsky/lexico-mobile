import 'package:equatable/equatable.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/settings/domain/entities/study_preferences.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

class StartStudySessionParams extends Equatable {
  const StartStudySessionParams({
    this.limit = StudyPreferences.defaultWordsPerSession,
  });

  final int limit;

  @override
  List<Object?> get props => [limit];
}

/// Hands back the stack for one sitting: the due cards, or, once everything
/// due is done, the cards coming due soonest. An [EmptyDeckFailure] only
/// when there are no words at all.
///
/// Studying ahead is graded like any review, so those words move further
/// out and earn XP as usual.
class StartStudySession
    implements UseCase<List<StudyCard>, StartStudySessionParams> {
  const StartStudySession(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<List<StudyCard>>> call(StartStudySessionParams params) async {
    final due = await _repository.dueCards(limit: params.limit);
    if (due case Err() || Success(value: [_, ...])) return due;

    final upcoming = await _repository.upcomingCards(limit: params.limit);
    return upcoming.fold<Result<List<StudyCard>>>(Result.failure, (cards) {
      if (cards.isEmpty) return const Result.failure(EmptyDeckFailure());
      return Result.success(cards);
    });
  }
}
