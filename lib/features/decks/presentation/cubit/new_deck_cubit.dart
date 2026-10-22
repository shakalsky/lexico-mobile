import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/entities/deck_language.dart';
import 'package:lexico/features/decks/domain/usecases/create_deck.dart';

enum NewDeckStatus { editing, saving, created }

class NewDeckState extends Equatable {
  const NewDeckState({
    this.status = NewDeckStatus.editing,
    this.message,
    this.deck,
  });

  final NewDeckStatus status;

  /// Why the last attempt was refused, shown under the form.
  final String? message;

  /// The deck the service created, once [status] is `created`.
  final Deck? deck;

  @override
  List<Object?> get props => [status, message, deck];
}

/// Drives the "New deck" sheet.
class NewDeckCubit extends Cubit<NewDeckState> {
  NewDeckCubit({required CreateDeck createDeck})
    : _createDeck = createDeck,
      super(const NewDeckState());

  final CreateDeck _createDeck;

  Future<void> submit({
    required String name,
    required DeckLanguage language,
  }) async {
    if (state.status == NewDeckStatus.saving) return;

    if (name.trim().isEmpty) {
      return emit(const NewDeckState(message: 'Give the deck a name.'));
    }

    emit(const NewDeckState(status: NewDeckStatus.saving));
    final result = await _createDeck(
      CreateDeckParams(name: name, language: language.label),
    );
    emit(
      result.fold(
        (failure) => NewDeckState(message: failure.message),
        (deck) => NewDeckState(status: NewDeckStatus.created, deck: deck),
      ),
    );
  }
}
