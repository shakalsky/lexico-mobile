import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

/// Deletes a word and its progress. This cannot be undone.
class DeleteWord implements UseCase<void, VocabWord> {
  const DeleteWord(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<void>> call(VocabWord word) => _repository.deleteWord(word);
}
