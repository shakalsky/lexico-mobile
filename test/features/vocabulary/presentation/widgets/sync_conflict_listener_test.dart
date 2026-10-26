import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/presentation/sync_conflict_message.dart';
import 'package:lexico/features/vocabulary/presentation/widgets/sync_conflict_listener.dart';

SyncConflict _conflict(
  SyncedChange change,
  SyncConflictReason reason, {
  String subject = 'el pan',
}) => SyncConflict(
  change: change,
  reason: reason,
  deckId: 'es-food',
  subject: subject,
  serverMessage: 'Body is wrong.',
);

void main() {
  group('message', () {
    test('explains a sentence another device added first', () {
      expect(
        _conflict(
          SyncedChange.wordAdded,
          SyncConflictReason.duplicateExample,
        ).message,
        "“el pan” wasn't added: the deck already has that example sentence.",
      );
      expect(
        _conflict(
          SyncedChange.wordEdited,
          SyncConflictReason.duplicateExample,
        ).message,
        'Your edit to “el pan” was undone: another word in the deck already '
        'has that example sentence.',
      );
    });

    test('explains a word or deck deleted elsewhere', () {
      expect(
        _conflict(SyncedChange.wordAdded, SyncConflictReason.deckGone).message,
        "“el pan” wasn't added: its deck was deleted.",
      );
      expect(
        _conflict(SyncedChange.wordEdited, SyncConflictReason.wordGone).message,
        'Your edit to “el pan” was lost: the word was deleted.',
      );
    });

    test("falls back to the service's own words", () {
      expect(
        _conflict(
          SyncedChange.deckCreated,
          SyncConflictReason.refused,
          subject: 'Food',
        ).message,
        "The deck “Food” couldn't be created: Body is wrong.",
      );
    });
  });

  testWidgets('shows each conflict in a snack bar', (tester) async {
    final conflicts = StreamController<SyncConflict>();
    addTearDown(conflicts.close);
    await tester.pumpWidget(
      MaterialApp(
        home: SyncConflictListener(
          conflicts: conflicts.stream,
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    conflicts.add(
      _conflict(SyncedChange.wordAdded, SyncConflictReason.duplicateExample),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(
      find.text(
        "“el pan” wasn't added: the deck already has that example sentence.",
      ),
      findsOneWidget,
    );
  });
}
