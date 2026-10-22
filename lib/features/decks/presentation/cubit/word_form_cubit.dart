import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:lexico/features/vocabulary/domain/usecases/add_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/edit_word.dart';

enum WordFormStatus { editing, saving, saved }

class WordFormState extends Equatable {
  const WordFormState({
    this.status = WordFormStatus.editing,
    this.message,
    this.word,
  });

  final WordFormStatus status;

  /// Why the last attempt was refused, shown under the form.
  final String? message;

  /// The word as the service stored it, once [status] is `saved`.
  final VocabWord? word;

  @override
  List<Object?> get props => [status, message, word];
}

/// Drives the word sheet, for a new word or an edit of an existing one.
class WordFormCubit extends Cubit<WordFormState> {
  /// Adds a new word to [deckId].
  WordFormCubit.add({required String deckId, required AddWord addWord})
    : original = null,
      _save = ((draft) => addWord(AddWordParams(deckId: deckId, word: draft))),
      super(const WordFormState());

  /// Edits [word].
  WordFormCubit.edit({required VocabWord word, required EditWord editWord})
    : original = word,
      _save = ((draft) => editWord(EditWordParams(word: word, draft: draft))),
      super(const WordFormState());

  /// The word being edited, or `null` for a new word.
  final VocabWord? original;
  final Future<Result<VocabWord>> Function(WordDraft draft) _save;

  bool get isEdit => original != null;

  Future<void> submit(WordDraft draft) async {
    if (state.status == WordFormStatus.saving) return;

    if (draft.questionExample.trim().isEmpty) {
      return emit(const WordFormState(message: 'Add an example sentence.'));
    }
    if (draft.answerExample.trim().isEmpty) {
      return emit(const WordFormState(message: 'Add its translation.'));
    }

    // Nothing changed: no need to ask the service.
    final original = this.original;
    if (original != null &&
        draft.normalized() == WordDraft.of(original).normalized()) {
      return emit(WordFormState(status: WordFormStatus.saved, word: original));
    }

    emit(const WordFormState(status: WordFormStatus.saving));
    final result = await _save(draft);
    emit(
      result.fold(
        (failure) => WordFormState(message: _explain(failure)),
        (word) => WordFormState(status: WordFormStatus.saved, word: word),
      ),
    );
  }

  String _explain(Failure failure) => switch (failure) {
    ServerFailure(
      code: 'question_examples_taken' || 'question_example_taken',
    ) =>
      'This example sentence is already in the deck.',
    ServerFailure(code: 'deck_not_found') => 'This deck no longer exists.',
    ServerFailure(code: 'word_not_found') => 'This word no longer exists.',
    _ => failure.message,
  };
}
