import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/delete_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/refresh_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/watch_sync_conflicts.dart';

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

/// Loads the words of one deck for its page: what is stored first, then
/// the word service's copy.
class DeckWordsCubit extends Cubit<DeckWordsState> {
  DeckWordsCubit({
    required this.deckId,
    required GetDeckWords getDeckWords,
    required RefreshDeckWords refreshDeckWords,
    required WatchSyncConflicts watchSyncConflicts,
    required DeleteWord deleteWord,
  }) : _getDeckWords = getDeckWords,
       _refreshDeckWords = refreshDeckWords,
       _deleteWord = deleteWord,
       super(const DeckWordsState()) {
    _conflicts = watchSyncConflicts()
        .where((conflict) => conflict.deckId == deckId)
        .listen(_onConflict);
  }

  final String deckId;
  final GetDeckWords _getDeckWords;
  final RefreshDeckWords _refreshDeckWords;
  final DeleteWord _deleteWord;
  late final StreamSubscription<SyncConflict> _conflicts;

  /// A change to this deck was refused and undone on the device: show the
  /// stored words as they are now. The app tells the learner why.
  Future<void> _onConflict(SyncConflict conflict) async {
    if (conflict.reason == SyncConflictReason.deckGone) {
      return emit(
        const DeckWordsState(
          status: DeckWordsStatus.failure,
          message: 'This deck no longer exists.',
        ),
      );
    }
    if (state.status != DeckWordsStatus.ready) return;
    final stored = await _getDeckWords(deckId);
    if (isClosed) return;
    if (stored case Success(value: final words)) {
      emit(DeckWordsState(status: DeckWordsStatus.ready, words: words));
    }
  }

  @override
  Future<void> close() async {
    await _conflicts.cancel();
    return super.close();
  }

  /// Shows the stored words at once, then refreshes them. A spinner shows
  /// only while nothing is stored. Once words are on screen, a refresh that
  /// can't reach the service changes nothing: offline is normal.
  Future<void> load() async {
    emit(const DeckWordsState());

    final stored = await _getDeckWords(deckId);
    if (stored case Success(value: [_, ...] && final words)) {
      emit(DeckWordsState(status: DeckWordsStatus.ready, words: words));
    }

    final fresh = await _refreshDeckWords(deckId);
    final failure = fresh.failureOrNull;
    if (failure == null) {
      return emit(
        DeckWordsState(
          status: DeckWordsStatus.ready,
          words: fresh.valueOrNull!,
        ),
      );
    }
    if (state.status != DeckWordsStatus.ready || _isGone(failure)) {
      emit(
        DeckWordsState(
          status: DeckWordsStatus.failure,
          message: failure.message,
        ),
      );
    }
  }

  /// Pull to refresh: keeps the list on screen, and on a failure keeps it
  /// and only reports the problem.
  Future<void> refresh() async {
    if (state.status != DeckWordsStatus.ready) return load();

    final result = await _refreshDeckWords(deckId);
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

  /// The service no longer has the deck, so stored words would mislead.
  bool _isGone(Failure failure) =>
      failure is ServerFailure && failure.code == 'deck_not_found';

  /// A word was just added; new words go last.
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

  /// Deletes [word]. It leaves the list at once; if the delete fails it
  /// goes back to its place and the problem is reported. Completes with
  /// whether it was deleted.
  Future<bool> deleteWord(VocabWord word) async {
    final index = state.words.indexWhere((w) => w.id == word.id);
    if (state.status != DeckWordsStatus.ready || index < 0) return false;

    emit(
      DeckWordsState(
        status: DeckWordsStatus.ready,
        words: [...state.words]..removeAt(index),
      ),
    );

    final result = await _deleteWord(word);
    final failure = result.failureOrNull;
    if (failure == null) return true;
    if (isClosed || state.status != DeckWordsStatus.ready) return false;

    final words = [...state.words];
    words.insert(index.clamp(0, words.length), word);
    emit(
      DeckWordsState(
        status: DeckWordsStatus.ready,
        words: words,
        notice: "Couldn't delete “${word.question}”: ${failure.message}",
      ),
    );
    return false;
  }
}
