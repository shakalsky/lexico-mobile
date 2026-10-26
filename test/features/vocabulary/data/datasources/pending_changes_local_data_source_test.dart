import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/pending_changes_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/models/pending_change.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';

void main() {
  late AppDatabase db;
  late PendingChangesLocalDataSourceImpl pending;

  final now = DateTime(2026, 8, 21, 10);
  const draft = WordDraft(
    questionShort: 'el pan',
    questionExample: 'Compro pan cada mañana.',
    answerExample: 'I buy bread every morning.',
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    pending = PendingChangesLocalDataSourceImpl(db);
  });

  tearDown(() => db.close());

  test('hands back every kind of change as it was queued', () async {
    const changes = <PendingChange>[
      DeckCreated(deckId: 'd1', name: 'Food', language: 'Español'),
      WordAdded(deckId: 'd1', wordId: 'w1', draft: draft),
      WordEdited(deckId: 'd1', wordId: 'w1', draft: draft),
      WordReviewed(deckId: 'd1', wordId: 'w1', correct: false),
    ];
    for (final change in changes) {
      await pending.add(change, now);
    }

    final read = <PendingChange>[];
    for (var next = await pending.oldest(); next != null;) {
      read.add(next.change);
      await pending.remove(next.id);
      next = await pending.oldest();
    }

    expect(read, changes);
  });

  test('knows which decks have changes waiting', () async {
    await pending.add(
      const WordReviewed(deckId: 'd1', wordId: 'w1', correct: true),
      now,
    );
    await pending.add(
      const WordReviewed(deckId: 'd1', wordId: 'w2', correct: true),
      now,
    );

    expect(await pending.hasChangesFor('d1'), isTrue);
    expect(await pending.hasChangesFor('d2'), isFalse);
    expect(await pending.deckIds(), {'d1'});
    expect(await pending.count(), 2);
  });

  test('counts failed attempts', () async {
    await pending.add(
      const WordReviewed(deckId: 'd1', wordId: 'w1', correct: true),
      now,
    );
    final queued = (await pending.oldest())!;

    await pending.markFailed(queued.id);

    expect((await pending.oldest())!.attempts, 1);
  });

  test('skips and deletes a change it cannot read', () async {
    await db
        .into(db.pendingChanges)
        .insert(
          PendingChangesCompanion.insert(
            kind: 'mystery',
            deckId: 'd1',
            payload: '{}',
            createdAt: now,
          ),
        );
    await pending.add(
      const WordReviewed(deckId: 'd1', wordId: 'w1', correct: true),
      now,
    );

    final next = (await pending.oldest())!;

    expect(next.change, isA<WordReviewed>());
    expect(await pending.count(), 1);
  });
}
