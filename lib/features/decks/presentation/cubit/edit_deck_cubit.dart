import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/usecases/edit_deck.dart';

enum EditDeckStatus { editing, saving, done }

class EditDeckState extends Equatable {
  const EditDeckState({
    this.status = EditDeckStatus.editing,
    this.message,
    this.deck,
  });

  final EditDeckStatus status;

  /// Why the last attempt was refused, shown under the form.
  final String? message;

  /// The edited deck once [status] is `done`, or `null` when nothing was
  /// changed.
  final Deck? deck;

  @override
  List<Object?> get props => [status, message, deck];
}

/// Drives the "Edit deck" sheet.
class EditDeckCubit extends Cubit<EditDeckState> {
  EditDeckCubit({required Deck deck, required EditDeck editDeck})
    : _deck = deck,
      _editDeck = editDeck,
      super(const EditDeckState());

  final Deck _deck;
  final EditDeck _editDeck;

  /// [language] is a display label, e.g. `Polski`.
  Future<void> submit({required String name, required String language}) async {
    if (state.status == EditDeckStatus.saving) return;

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return emit(const EditDeckState(message: 'Give the deck a name.'));
    }
    if (trimmed == _deck.name && language == _deck.language) {
      return emit(const EditDeckState(status: EditDeckStatus.done));
    }

    emit(const EditDeckState(status: EditDeckStatus.saving));
    final result = await _editDeck(
      EditDeckParams(deck: _deck, name: trimmed, language: language),
    );
    emit(
      result.fold(
        (failure) => EditDeckState(message: failure.message),
        (deck) => EditDeckState(status: EditDeckStatus.done, deck: deck),
      ),
    );
  }
}
