import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/repositories/decks_repository.dart';

class GetDecks implements UseCase<List<Deck>, NoParams> {
  const GetDecks(this._repository);

  final DecksRepository _repository;

  @override
  Future<Result<List<Deck>>> call(NoParams params) => _repository.getDecks();
}
