part of 'decks_bloc.dart';

enum DecksStatus { initial, loading, ready, failure }

class DecksState extends Equatable {
  const DecksState({
    this.status = DecksStatus.initial,
    this.decks = const [],
    this.studiedIds = const {},
    this.pendingIds = const {},
    this.message,
    this.notice,
  });

  final DecksStatus status;
  final List<Deck> decks;

  /// Decks in the study rotation.
  final Set<String> studiedIds;

  /// Decks whose Study switch is still being saved.
  final Set<String> pendingIds;

  /// Why the list could not be loaded, with [DecksStatus.failure].
  final String? message;

  /// A one-off note for a snack bar, e.g. a failed refresh. Cleared by the
  /// next state.
  final String? notice;

  bool isStudied(Deck deck) => studiedIds.contains(deck.id);

  DecksState copyWith({
    DecksStatus? status,
    List<Deck>? decks,
    Set<String>? studiedIds,
    Set<String>? pendingIds,
    String? message,
    String? notice,
  }) => DecksState(
    status: status ?? this.status,
    decks: decks ?? this.decks,
    studiedIds: studiedIds ?? this.studiedIds,
    pendingIds: pendingIds ?? this.pendingIds,
    message: message,
    notice: notice,
  );

  @override
  List<Object?> get props => [
    status,
    decks,
    studiedIds,
    pendingIds,
    message,
    notice,
  ];
}
