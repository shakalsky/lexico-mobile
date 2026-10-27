import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/repositories/decks_repository.dart';

/// Deletes a deck with all its words and their progress. This cannot be
/// undone.
class DeleteDeck implements UseCase<void, Deck> {
  const DeleteDeck(this._repository);

  final DecksRepository _repository;

  @override
  Future<Result<void>> call(Deck deck) => _repository.deleteDeck(deck);
}
