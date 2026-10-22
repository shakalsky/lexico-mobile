import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';

abstract interface class DecksRepository {
  /// Every deck on the word service, oldest first.
  Future<Result<List<Deck>>> getDecks();

  /// Creates an empty deck; the service picks its id.
  Future<Result<Deck>> createDeck({
    required String name,
    required String language,
  });
}
