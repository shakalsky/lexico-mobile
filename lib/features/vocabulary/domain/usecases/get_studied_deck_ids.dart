import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

class GetStudiedDeckIds implements UseCase<Set<String>, NoParams> {
  const GetStudiedDeckIds(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<Set<String>>> call(NoParams params) =>
      _repository.studiedDeckIds();
}
