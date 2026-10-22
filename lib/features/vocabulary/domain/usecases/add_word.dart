import 'package:equatable/equatable.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

class AddWordParams extends Equatable {
  const AddWordParams({required this.deckId, required this.word});

  final String deckId;
  final WordDraft word;

  @override
  List<Object?> get props => [deckId, word];
}

/// Appends one word to a deck, with its text normalized.
class AddWord implements UseCase<VocabWord, AddWordParams> {
  const AddWord(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<VocabWord>> call(AddWordParams params) =>
      _repository.addWord(params.deckId, params.word.normalized());
}
