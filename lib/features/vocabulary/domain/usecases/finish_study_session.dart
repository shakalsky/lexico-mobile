import 'package:equatable/equatable.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_outcome.dart';
import 'package:lexico/features/vocabulary/domain/entities/session_summary.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

class FinishStudySessionParams extends Equatable {
  const FinishStudySessionParams({
    required this.startedAt,
    required this.endedAt,
    required this.outcomes,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final List<ReviewOutcome> outcomes;

  @override
  List<Object?> get props => [startedAt, endedAt, outcomes];
}

/// Logs the session, awards XP and builds the summary shown at the end.
class FinishStudySession
    implements UseCase<SessionSummary, FinishStudySessionParams> {
  const FinishStudySession(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<SessionSummary>> call(FinishStudySessionParams params) async {
    final correct = params.outcomes.where((o) => o.isCorrect).length;
    final xpEarned = params.outcomes.fold(0, (sum, o) => sum + o.xpEarned);

    final streakResult = await _repository.logSession(
      startedAt: params.startedAt,
      endedAt: params.endedAt,
      reviewedCount: params.outcomes.length,
      correctCount: correct,
      xpEarned: xpEarned,
    );

    return streakResult.map(
      (streakDays) => SessionSummary(
        reviewedCount: params.outcomes.length,
        correctCount: correct,
        xpEarned: xpEarned,
        streakDays: streakDays,
        missedWords: params.outcomes
            .where((o) => !o.isCorrect)
            .map((o) => o.word)
            .toList(growable: false),
      ),
    );
  }
}
