import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/entities/learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

class GetLearnerStats implements UseCase<LearnerStats, NoParams> {
  const GetLearnerStats(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<LearnerStats>> call(NoParams params) =>
      _repository.learnerStats();
}
