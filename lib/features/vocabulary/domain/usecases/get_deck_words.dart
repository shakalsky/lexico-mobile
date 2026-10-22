import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

/// Every word of one deck, given its id.
class GetDeckWords implements UseCase<List<VocabWord>, String> {
  const GetDeckWords(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<List<VocabWord>>> call(String deckId) =>
      _repository.deckWords(deckId);
}
