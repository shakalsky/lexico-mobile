import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

/// Brings the stored words of one deck up to date with the word service.
class RefreshDeckWords implements UseCase<List<VocabWord>, String> {
  const RefreshDeckWords(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<List<VocabWord>>> call(String deckId) =>
      _repository.refreshDeckWords(deckId);
}
