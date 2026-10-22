import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/repositories/decks_repository.dart';

/// Replays queued results; the last one repeats once the queue runs down.
class FakeDecksRepository implements DecksRepository {
  FakeDecksRepository({
    List<Result<List<Deck>>>? decks,
    List<Result<Deck>>? created,
  }) : _decks = decks ?? [const Result.success([])],
       _created = created ?? [];

  final List<Result<List<Deck>>> _decks;
  final List<Result<Deck>> _created;

  int getCalls = 0;
  final List<({String name, String language})> createCalls = [];

  @override
  Future<Result<List<Deck>>> getDecks() async {
    getCalls++;
    return _decks.length > 1 ? _decks.removeAt(0) : _decks.single;
  }

  @override
  Future<Result<Deck>> createDeck({
    required String name,
    required String language,
  }) async {
    createCalls.add((name: name, language: language));
    return _created.length > 1 ? _created.removeAt(0) : _created.single;
  }
}

Deck testDeckEntity(String id, {String? name, int day = 8}) => Deck(
  id: id,
  name: name ?? id,
  language: 'Español',
  createdAt: DateTime(2026, 10, day, 12),
);
