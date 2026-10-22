import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/usecases/get_decks.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_studied_deck_ids.dart';
import 'package:lexico/features/vocabulary/domain/usecases/set_deck_studied.dart';

part 'decks_event.dart';
part 'decks_state.dart';

class DecksBloc extends Bloc<DecksEvent, DecksState> {
  DecksBloc({
    required GetDecks getDecks,
    required GetStudiedDeckIds getStudiedDeckIds,
    required SetDeckStudied setDeckStudied,
  }) : _getDecks = getDecks,
       _getStudiedDeckIds = getStudiedDeckIds,
       _setDeckStudied = setDeckStudied,
       super(const DecksState()) {
    on<DecksRequested>(_onRequested);
    on<DecksRefreshed>(_onRefreshed);
    on<DeckAdded>(_onDeckAdded);
    on<DeckStudyToggled>(_onStudyToggled);
  }

  final GetDecks _getDecks;
  final GetStudiedDeckIds _getStudiedDeckIds;
  final SetDeckStudied _setDeckStudied;

  Future<void> _onRequested(DecksRequested event, Emitter<DecksState> emit) =>
      _load(emit);

  Future<void> _load(Emitter<DecksState> emit) async {
    emit(state.copyWith(status: DecksStatus.loading));
    final result = await _fetch();
    emit(
      result.fold(
        (failure) => state.copyWith(
          status: DecksStatus.failure,
          message: failure.message,
        ),
        (loaded) => state.copyWith(
          status: DecksStatus.ready,
          decks: loaded.decks,
          studiedIds: loaded.studiedIds,
        ),
      ),
    );
  }

  /// The decks from the service, and which of them are studied here.
  Future<Result<({List<Deck> decks, Set<String> studiedIds})>> _fetch() async {
    final (decks, studied) = await (
      _getDecks(const NoParams()),
      _getStudiedDeckIds(const NoParams()),
    ).wait;

    final failure = decks.failureOrNull ?? studied.failureOrNull;
    if (failure != null) return Result.failure(failure);
    return Result.success((
      decks: decks.valueOrNull!,
      studiedIds: studied.valueOrNull!,
    ));
  }

  /// The list is oldest first, so a new deck goes last. Without a list on
  /// screen yet, load the whole thing instead.
  Future<void> _onDeckAdded(DeckAdded event, Emitter<DecksState> emit) async {
    if (state.status != DecksStatus.ready) return _load(emit);
    emit(state.copyWith(decks: [...state.decks, event.deck]));
  }

  /// Flips the button at once, then saves; a failed save flips it back.
  Future<void> _onStudyToggled(
    DeckStudyToggled event,
    Emitter<DecksState> emit,
  ) async {
    final deckId = event.deckId;
    if (state.pendingIds.contains(deckId)) return;

    final studied = !state.studiedIds.contains(deckId);
    emit(
      state.copyWith(
        studiedIds: _toggled(state.studiedIds, deckId, on: studied),
        pendingIds: {...state.pendingIds, deckId},
      ),
    );

    final result = await _setDeckStudied(
      SetDeckStudiedParams(deckId: deckId, studied: studied),
    );

    final pendingIds = {...state.pendingIds}..remove(deckId);
    emit(
      result.fold(
        (failure) => state.copyWith(
          studiedIds: _toggled(state.studiedIds, deckId, on: !studied),
          pendingIds: pendingIds,
          notice: "Couldn't save: ${failure.message}",
        ),
        (_) => state.copyWith(pendingIds: pendingIds),
      ),
    );
  }

  Set<String> _toggled(Set<String> ids, String id, {required bool on}) =>
      on ? {...ids, id} : ({...ids}..remove(id));

  /// Keeps the current list on screen while reloading; a failed refresh
  /// leaves it in place and only reports the problem.
  Future<void> _onRefreshed(
    DecksRefreshed event,
    Emitter<DecksState> emit,
  ) async {
    try {
      if (state.status != DecksStatus.ready) return await _load(emit);

      final result = await _fetch();
      emit(
        result.fold(
          (failure) =>
              state.copyWith(notice: "Couldn't refresh: ${failure.message}"),
          (loaded) => state.copyWith(
            decks: loaded.decks,
            studiedIds: loaded.studiedIds,
          ),
        ),
      );
    } finally {
      event.done?.complete();
    }
  }
}
