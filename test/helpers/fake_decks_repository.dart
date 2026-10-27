import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/repositories/decks_repository.dart';

/// [stored] is what is on the device. [decks] is what each refresh answers,
/// replayed in order; the last one repeats once the queue runs down.
class FakeDecksRepository implements DecksRepository {
  FakeDecksRepository({
    List<Result<List<Deck>>>? decks,
    List<Result<Deck>>? created,
    List<Deck> stored = const [],
  }) : _decks = decks ?? [const Result.success([])],
       _created = created ?? [],
       stored = [...stored];

  final List<Result<List<Deck>>> _decks;
  final List<Result<Deck>> _created;
  final List<Deck> stored;

  int refreshCalls = 0;
  final List<({String name, String language})> createCalls = [];

  @override
  Future<Result<List<Deck>>> getDecks() async => Result.success([...stored]);

  @override
  Future<Result<List<Deck>>> refreshDecks() async {
    refreshCalls++;
    final result = _decks.length > 1 ? _decks.removeAt(0) : _decks.single;
    if (result case Success(:final value)) {
      stored
        ..clear()
        ..addAll(value);
    }
    return result;
  }

  @override
  Future<Result<Deck>> createDeck({
    required String name,
    required String language,
  }) async {
    createCalls.add((name: name, language: language));
    final result = _created.length > 1 ? _created.removeAt(0) : _created.single;
    if (result case Success(:final value)) stored.add(value);
    return result;
  }

  /// When set, [deleteDeck] fails with it instead of deleting.
  Failure? deleteFailure;
  final List<Deck> deleted = [];

  @override
  Future<Result<void>> deleteDeck(Deck deck) async {
    final failure = deleteFailure;
    if (failure != null) return Result.failure(failure);
    deleted.add(deck);
    stored.removeWhere((d) => d.id == deck.id);
    return const Result.success(null);
  }
}

Deck testDeckEntity(String id, {String? name, int day = 8}) => Deck(
  id: id,
  name: name ?? id,
  language: 'Español',
  createdAt: DateTime(2026, 10, day, 12),
);
