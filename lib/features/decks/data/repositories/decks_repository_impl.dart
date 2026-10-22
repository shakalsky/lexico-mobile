import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/error/exception_mapper.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/decks/data/datasources/decks_remote_data_source.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/repositories/decks_repository.dart';

class DecksRepositoryImpl implements DecksRepository {
  const DecksRepositoryImpl(this._remote);

  final DecksRemoteDataSource _remote;

  @override
  Future<Result<List<Deck>>> getDecks() async {
    try {
      final decks = await _remote.fetchDecks();
      return Result.success(
        decks.map((dto) => dto.toEntity()).toList(growable: false),
      );
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  @override
  Future<Result<Deck>> createDeck({
    required String name,
    required String language,
  }) async {
    try {
      final deck = await _remote.createDeck(name: name, language: language);
      return Result.success(deck.toEntity());
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }
}
