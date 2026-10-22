part of 'decks_bloc.dart';

sealed class DecksEvent extends Equatable {
  const DecksEvent();

  @override
  List<Object?> get props => const [];
}

/// Load the list, showing a spinner until it arrives.
final class DecksRequested extends DecksEvent {
  const DecksRequested();
}

/// A deck was just created; put it at the end of the list.
final class DeckAdded extends DecksEvent {
  const DeckAdded(this.deck);

  final Deck deck;

  @override
  List<Object?> get props => [deck];
}

/// The Study / Studying button of a deck was tapped.
final class DeckStudyToggled extends DecksEvent {
  const DeckStudyToggled(this.deckId);

  final String deckId;

  @override
  List<Object?> get props => [deckId];
}

/// Pull to refresh: reload without hiding the list already shown.
/// [done] completes once the reload has finished, whatever its outcome.
final class DecksRefreshed extends DecksEvent {
  const DecksRefreshed([this.done]);

  final Completer<void>? done;
}
