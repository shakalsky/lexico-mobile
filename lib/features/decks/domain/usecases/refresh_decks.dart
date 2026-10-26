import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/usecase/use_case.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/repositories/decks_repository.dart';

/// Brings the stored decks up to date with the word service.
class RefreshDecks implements UseCase<List<Deck>, NoParams> {
  const RefreshDecks(this._repository);

  final DecksRepository _repository;

  @override
  Future<Result<List<Deck>>> call(NoParams params) =>
      _repository.refreshDecks();
}
