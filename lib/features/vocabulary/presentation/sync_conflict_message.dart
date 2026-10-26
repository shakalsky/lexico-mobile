import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';

extension SyncConflictMessage on SyncConflict {
  /// What to tell the learner: what was lost, and why.
  String get message {
    final what = '“$subject”';
    return switch ((change, reason)) {
      (SyncedChange.wordAdded, SyncConflictReason.duplicateExample) =>
        "$what wasn't added: the deck already has that example sentence.",
      (SyncedChange.wordEdited, SyncConflictReason.duplicateExample) =>
        'Your edit to $what was undone: another word in the deck already '
            'has that example sentence.',
      (SyncedChange.wordAdded, SyncConflictReason.deckGone) =>
        "$what wasn't added: its deck was deleted.",
      (
        SyncedChange.wordEdited,
        SyncConflictReason.wordGone || SyncConflictReason.deckGone,
      ) =>
        'Your edit to $what was lost: the word was deleted.',
      (SyncedChange.deckCreated, _) =>
        "The deck $what couldn't be created: $serverMessage",
      (SyncedChange.wordAdded, _) => "$what wasn't added: $serverMessage",
      (SyncedChange.wordEdited, _) =>
        'Your edit to $what was undone: $serverMessage',
    };
  }
}
