import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';

/// Offline first: decks are read from the device, and new ones reach the
/// word service in the background.
abstract interface class DecksRepository {
  /// Every deck stored on the device, oldest first. Never touches the
  /// network.
  Future<Result<List<Deck>>> getDecks();

  /// Sends changes made offline, then fetches the deck list from the word
  /// service, stores it and returns the stored decks. Fails when the service
  /// can't be reached.
  Future<Result<List<Deck>>> refreshDecks();

  /// Creates an empty deck on the device, at once; it reaches the word
  /// service with the next sync.
  Future<Result<Deck>> createDeck({
    required String name,
    required String language,
  });
}
