import 'package:equatable/equatable.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/repositories/decks_repository.dart';

class EditDeckParams extends Equatable {
  const EditDeckParams({
    required this.deck,
    required this.name,
    required this.language,
  });

  final Deck deck;
  final String name;

  /// Display label of the language, e.g. `Polski`.
  final String language;

  @override
  List<Object?> get props => [deck, name, language];
}

/// Gives a deck a new name, language, or both. Completes with the edited
/// deck.
class EditDeck implements UseCase<Deck, EditDeckParams> {
  const EditDeck(this._repository);

  final DecksRepository _repository;

  @override
  Future<Result<Deck>> call(EditDeckParams params) => _repository.editDeck(
    params.deck,
    name: params.name.trim(),
    language: params.language.trim(),
  );
}
