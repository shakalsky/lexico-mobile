import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

/// Makes sure the device holds the studied decks, refreshing them when
/// possible.
class SyncVocabulary implements UseCase<int, NoParams> {
  const SyncVocabulary(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<int>> call(NoParams params) => _repository.syncDecks();
}
