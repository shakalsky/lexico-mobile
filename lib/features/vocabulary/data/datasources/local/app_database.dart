import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:lexico/core/network/api_config.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Words, Reviews, StudyDecks, StudySessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'lexico'));

  /// Test seam: an in-memory database with no platform dependencies.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

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
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
