import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lexico_migration');
    file = File('${dir.path}/lexico.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('upgrading from version 1 adds decks and the change queue', () async {
    // A version 1 database: today's schema without the two new tables.
    final fresh = AppDatabase.forTesting(NativeDatabase(file));
    await fresh.customSelect('SELECT 1').get();
    await fresh.customStatement('DROP TABLE decks');
    await fresh.customStatement('DROP TABLE pending_changes');
    await fresh.customStatement('PRAGMA user_version = 1');
    await fresh.close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);

    expect(await upgraded.select(upgraded.decks).get(), isEmpty);
    expect(await upgraded.select(upgraded.pendingChanges).get(), isEmpty);
    expect(await upgraded.select(upgraded.studyDecks).get(), hasLength(1));
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 2);
  });
}
