import 'package:drift/drift.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/local_transaction.dart';

/// The decks stored on the device.
abstract interface class DecksLocalDataSource {
  /// Every stored deck, oldest first.
  Future<List<DeckRow>> decks();

  Future<Set<String>> deckIds();

  /// Stores [deck] unless a deck with its id is already stored.
  Future<void> addDeck(DeckRow deck);

  /// Stores [decks], overwriting the stored copies.
  Future<void> saveDecks(List<DeckRow> decks);

  /// Changes the fields given of [deckId]. Does nothing if it is not stored.
  Future<void> editDeck(String deckId, {String? name, String? language});
}

class DecksLocalDataSourceImpl implements DecksLocalDataSource {
  const DecksLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<DeckRow>> decks() => guardLocal(
    () =>
        (_db.select(_db.decks)..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get(),
  );

  @override
  Future<Set<String>> deckIds() => guardLocal(() async {
    final rows = await (_db.selectOnly(
      _db.decks,
    )..addColumns([_db.decks.id])).get();
    return {
      for (final row in rows)
        if (row.read(_db.decks.id) case final String id) id,
    };
  });

  @override
  Future<void> addDeck(DeckRow deck) => guardLocal(
    () => _db.into(_db.decks).insert(deck, mode: InsertMode.insertOrIgnore),
  );

  @override
  Future<void> saveDecks(List<DeckRow> decks) => guardLocal(
    () =>
        _db.batch((batch) => batch.insertAllOnConflictUpdate(_db.decks, decks)),
  );

  @override
  Future<void> editDeck(String deckId, {String? name, String? language}) =>
      guardLocal(
        () => (_db.update(_db.decks)..where((t) => t.id.equals(deckId))).write(
          DecksCompanion(
            name: Value.absentIfNull(name),
            language: Value.absentIfNull(language),
          ),
        ),
      );
}
