import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/local_transaction.dart';
import 'package:lexico/features/vocabulary/data/models/pending_change.dart';

/// The queue of changes made on the device that the word service has not
/// seen yet.
abstract interface class PendingChangesLocalDataSource {
  Future<void> add(PendingChange change, DateTime now);

  /// The change that has waited longest, or `null` when nothing waits.
  Future<QueuedChange?> oldest();

  Future<void> remove(int id);

  /// Counts one more failed attempt at sending [id].
  Future<void> markFailed(int id);

  /// Whether [deckId] has changes waiting. Such a deck is not overwritten by
  /// a sync, since the device holds the newest version of it.
  Future<bool> hasChangesFor(String deckId);

  /// Every deck with changes waiting.
  Future<Set<String>> deckIds();

  /// Decks deleted on the device that the service hasn't heard of yet.
  Future<Set<String>> deletedDeckIds();

  /// Drops every change waiting for [deckId].
  Future<void> removeForDeck(String deckId);

  Future<int> count();
}

class PendingChangesLocalDataSourceImpl
    implements PendingChangesLocalDataSource {
  const PendingChangesLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  @override
  Future<void> add(PendingChange change, DateTime now) => guardLocal(
    () => _db
        .into(_db.pendingChanges)
        .insert(
          PendingChangesCompanion.insert(
            kind: change.kind,
            deckId: change.deckId,
            payload: jsonEncode(change.payload),
            createdAt: now,
          ),
        ),
  );

  /// A change that can't be read back is deleted, so it can't block the
  /// queue.
  @override
  Future<QueuedChange?> oldest() => guardLocal(() async {
    while (true) {
      final row =
          await (_db.select(_db.pendingChanges)
                ..orderBy([(t) => OrderingTerm.asc(t.id)])
                ..limit(1))
              .getSingleOrNull();
      if (row == null) return null;

      try {
        return QueuedChange(
          id: row.id,
          attempts: row.attempts,
          change: PendingChange.fromStored(
            kind: row.kind,
            deckId: row.deckId,
            payload: jsonDecode(row.payload) as Map<String, dynamic>,
          ),
        );
      } on FormatException {
        await remove(row.id);
        // A field of the wrong type surfaces as a TypeError from the casts.
        // ignore: avoid_catching_errors
      } on TypeError {
        await remove(row.id);
      }
    }
  });

  @override
  Future<void> remove(int id) => guardLocal(
    () => (_db.delete(_db.pendingChanges)..where((t) => t.id.equals(id))).go(),
  );

  @override
  Future<void> markFailed(int id) => guardLocal(
    () => (_db.update(_db.pendingChanges)..where((t) => t.id.equals(id))).write(
      PendingChangesCompanion.custom(
        attempts: _db.pendingChanges.attempts + const Constant(1),
      ),
    ),
  );

  @override
  Future<bool> hasChangesFor(String deckId) => guardLocal(
    () async =>
        await _db.pendingChanges
            .count(where: (t) => t.deckId.equals(deckId))
            .getSingle() >
        0,
  );

  @override
  Future<Set<String>> deckIds() => guardLocal(() async {
    final query = _db.selectOnly(_db.pendingChanges, distinct: true)
      ..addColumns([_db.pendingChanges.deckId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(_db.pendingChanges.deckId) case final String id) id,
    };
  });

  @override
  Future<Set<String>> deletedDeckIds() => guardLocal(() async {
    final query = _db.selectOnly(_db.pendingChanges, distinct: true)
      ..addColumns([_db.pendingChanges.deckId])
      ..where(_db.pendingChanges.kind.equals(DeckDeleted.kindName));
    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(_db.pendingChanges.deckId) case final String id) id,
    };
  });

  @override
  Future<void> removeForDeck(String deckId) => guardLocal(
    () => (_db.delete(
      _db.pendingChanges,
    )..where((t) => t.deckId.equals(deckId))).go(),
  );

  @override
  Future<int> count() =>
      guardLocal(() => _db.pendingChanges.count().getSingle());
}
