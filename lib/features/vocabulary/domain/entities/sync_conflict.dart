import 'package:equatable/equatable.dart';

/// What the learner did offline that the word service refused.
enum SyncedChange {
  deckCreated,
  deckDeleted,
  wordAdded,
  wordEdited,
  wordDeleted,
}

/// Why the word service refused it.
enum SyncConflictReason {
  /// The deck already has a word with that example sentence, e.g. added from
  /// another device.
  duplicateExample,

  /// The deck was deleted on the service.
  deckGone,

  /// The word was deleted on the service.
  wordGone,

  /// Anything else the service refused.
  refused,
}

/// A change made on the device that the word service refused. The device
/// has already been brought back in line with the service, so the change is
/// gone; this is only there to tell the learner.
class SyncConflict extends Equatable {
  const SyncConflict({
    required this.change,
    required this.reason,
    required this.deckId,
    required this.subject,
    required this.serverMessage,
  });

  final SyncedChange change;
  final SyncConflictReason reason;
  final String deckId;

  /// What the change was about, as the learner knows it: the word, or the
  /// deck's name.
  final String subject;

  /// The service's own explanation, for developers.
  final String serverMessage;

  @override
  List<Object?> get props => [change, reason, deckId, subject, serverMessage];
}
