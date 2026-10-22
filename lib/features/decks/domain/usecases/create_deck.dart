import 'package:equatable/equatable.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/repositories/decks_repository.dart';

class CreateDeckParams extends Equatable {
  const CreateDeckParams({required this.name, required this.language});

  final String name;
  final String language;

  @override
  List<Object?> get props => [name, language];
}

class CreateDeck implements UseCase<Deck, CreateDeckParams> {
  const CreateDeck(this._repository);

  final DecksRepository _repository;

  @override
  Future<Result<Deck>> call(CreateDeckParams params) => _repository.createDeck(
    name: params.name.trim(),
    language: params.language.trim(),
  );
}
