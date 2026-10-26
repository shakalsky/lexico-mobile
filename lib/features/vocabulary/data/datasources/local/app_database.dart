import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:lexico/core/network/api_config.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Decks, Words, Reviews, StudyDecks, StudySessions, PendingChanges],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'lexico'));

  /// Test seam: an in-memory database with no platform dependencies.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // A fresh install studies the core deck until the learner says
      // otherwise.
      await into(
        studyDecks,
      ).insert(StudyDecksCompanion.insert(deckId: ApiConfig.defaultDeckId));
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Offline first: decks are stored too, and changes wait in a queue.
        // The deck list fills on the next sync.
        await m.createTable(decks);
        await m.createTable(pendingChanges);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
