import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_deck_words.dart';

enum DeckWordsStatus { loading, ready, failure }

class DeckWordsState extends Equatable {
  const DeckWordsState({
    this.status = DeckWordsStatus.loading,
    this.words = const [],
    this.message,
    this.notice,
  });

  final DeckWordsStatus status;
  final List<VocabWord> words;

  /// Why the words could not be loaded, with [DeckWordsStatus.failure].
  final String? message;

  /// A one-off note for a snack bar, e.g. a failed refresh.
  final String? notice;

  @override
  List<Object?> get props => [status, words, message, notice];
}

/// Loads the words of one deck for its page.
class DeckWordsCubit extends Cubit<DeckWordsState> {
  DeckWordsCubit({required this.deckId, required GetDeckWords getDeckWords})
    : _getDeckWords = getDeckWords,
      super(const DeckWordsState());

  final String deckId;
  final GetDeckWords _getDeckWords;

  /// Shows a spinner until the words arrive.
  Future<void> load() async {
    emit(const DeckWordsState());
    final result = await _getDeckWords(deckId);
    emit(
      result.fold(
        (failure) => DeckWordsState(
          status: DeckWordsStatus.failure,
          message: failure.message,
        ),
        (words) => DeckWordsState(status: DeckWordsStatus.ready, words: words),
      ),
    );
  }

  /// Pull to refresh: keeps the list on screen, and on a failure keeps it
  /// and only reports the problem.
  Future<void> refresh() async {
    if (state.status != DeckWordsStatus.ready) return load();

    final result = await _getDeckWords(deckId);
    emit(
      result.fold(
        (failure) => DeckWordsState(
          status: DeckWordsStatus.ready,
          words: state.words,
          notice: "Couldn't refresh: ${failure.message}",
        ),
        (words) => DeckWordsState(status: DeckWordsStatus.ready, words: words),
      ),
    );
  }

  /// A word was just added; the service appends, so it goes last.
  /// Without a list on screen yet, it loads the whole deck instead.
  Future<void> wordAdded(VocabWord word) async {
    if (state.status != DeckWordsStatus.ready) return load();
    emit(
      DeckWordsState(
        status: DeckWordsStatus.ready,
        words: [...state.words, word],
      ),
    );
  }

  /// A word was just edited; it keeps its place in the list.
  void wordEdited(VocabWord word) {
    if (state.status != DeckWordsStatus.ready) return;
    emit(
      DeckWordsState(
        status: DeckWordsStatus.ready,
        words: [
          for (final existing in state.words)
            existing.id == word.id ? word : existing,
        ],
      ),
    );
  }
}
