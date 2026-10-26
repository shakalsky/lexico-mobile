import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/error/exception_mapper.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/utils/id_generator.dart';
import 'package:lexico/features/decks/data/datasources/decks_local_data_source.dart';
import 'package:lexico/features/decks/data/mappers/deck_mappers.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/repositories/decks_repository.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/local_transaction.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/pending_changes_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/models/pending_change.dart';
import 'package:lexico/features/vocabulary/data/sync/sync_engine.dart';

class DecksRepositoryImpl implements DecksRepository {
  DecksRepositoryImpl({
    required DecksLocalDataSource local,
    required PendingChangesLocalDataSource pending,
    required LocalTransaction transaction,
    required SyncEngine sync,
    DateTime Function() clock = DateTime.now,
    IdGenerator newId = uuidV4,
  }) : _local = local,
       _pending = pending,
       _transaction = transaction,
       _sync = sync,
       _clock = clock,
       _newId = newId;

  final DecksLocalDataSource _local;
  final PendingChangesLocalDataSource _pending;
  final LocalTransaction _transaction;
  final SyncEngine _sync;
  final DateTime Function() _clock;
  final IdGenerator _newId;

  @override
  Future<Result<List<Deck>>> getDecks() async {
    try {
      final rows = await _local.decks();
      return Result.success([for (final row in rows) row.toEntity()]);
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
  }

  @override
  Future<Result<List<Deck>>> refreshDecks() async {
    try {
      await _sync.refreshDecks();
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }
    return getDecks();
  }

  @override
  Future<Result<Deck>> createDeck({
    required String name,
    required String language,
  }) async {
    final now = _clock();
    final deck = DeckRow(
      id: _newId(),
      name: name,
      language: language,
      createdAt: now,
    );
    try {
      await _transaction(() async {
        await _local.addDeck(deck);
        await _pending.add(
          DeckCreated(deckId: deck.id, name: name, language: language),
          now,
        );
      });
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }

    _sync.schedulePush();
    return Result.success(deck.toEntity());
  }
}
