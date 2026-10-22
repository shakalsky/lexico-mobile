import 'package:equatable/equatable.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

class EditWordParams extends Equatable {
  const EditWordParams({required this.word, required this.draft});

  /// The word as it is now.
  final VocabWord word;

  /// Its new text.
  final WordDraft draft;

  @override
  List<Object?> get props => [word, draft];
}

/// Replaces a word's text, normalized. Its id, deck, place and counters stay.
class EditWord implements UseCase<VocabWord, EditWordParams> {
  const EditWord(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<VocabWord>> call(EditWordParams params) =>
      _repository.editWord(params.word, params.draft.normalized());
}
