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
import 'package:lexico/features/vocabulary/data/datasources/local/vocabulary_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/models/pending_change.dart';
import 'package:lexico/features/vocabulary/data/sync/sync_engine.dart';

class DecksRepositoryImpl implements DecksRepository {
  DecksRepositoryImpl({
    required DecksLocalDataSource local,
    required VocabularyLocalDataSource words,
    required PendingChangesLocalDataSource pending,
    required LocalTransaction transaction,
    required SyncEngine sync,
    DateTime Function() clock = DateTime.now,
    IdGenerator newId = uuidV4,
  }) : _local = local,
       _words = words,
       _pending = pending,
       _transaction = transaction,
       _sync = sync,
       _clock = clock,
       _newId = newId;

  final DecksLocalDataSource _local;

  /// Deck words, removed along with their deck.
  final VocabularyLocalDataSource _words;
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
    return await getDecks();
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

  /// Only fields that differ from [deck] are queued; keeping both queues
  /// nothing.
  @override
  Future<Result<Deck>> editDeck(
    Deck deck, {
    required String name,
    required String language,
  }) async {
    final newName = name == deck.name ? null : name;
    final newLanguage = language == deck.language ? null : language;
    if (newName == null && newLanguage == null) return Result.success(deck);

    try {
      await _transaction(() async {
        await _local.editDeck(deck.id, name: newName, language: newLanguage);
        await _pending.add(
          DeckEdited(
            deckId: deck.id,
            deckName: name,
            name: newName,
            language: newLanguage,
          ),
          _clock(),
        );
      });
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }

    _sync.schedulePush();
    return Result.success(
      Deck(
        id: deck.id,
        name: name,
        language: language,
        createdAt: deck.createdAt,
      ),
    );
  }

  /// Changes still waiting for the deck are dropped: the deletion makes
  /// them moot, and a deck created here may never reach the service at all.
  /// The deletion is still sent, in case its creation already got through.
  @override
  Future<Result<void>> deleteDeck(Deck deck) async {
    try {
      await _transaction(() async {
        await _words.deleteDeck(deck.id);
        await _pending.removeForDeck(deck.id);
        await _pending.add(
          DeckDeleted(deckId: deck.id, name: deck.name),
          _clock(),
        );
      });
    } on AppException catch (error) {
      return Result.failure(error.toFailure());
    }

    _sync.schedulePush();
    return const Result.success(null);
  }
}
