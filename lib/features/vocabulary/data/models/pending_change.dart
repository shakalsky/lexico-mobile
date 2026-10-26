import 'package:equatable/equatable.dart';
import 'package:lexico/features/vocabulary/data/models/word_draft_json.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';

/// One change made on the device, waiting to be sent to the word service.
///
/// Ids are chosen on the device, so sending the same change twice is safe
/// for everything but [WordReviewed]: the service counts every answer.
sealed class PendingChange extends Equatable {
  const PendingChange({required this.deckId});

  /// Rebuilds a change from its stored [kind] and [payload]. Throws a
  /// [FormatException] for a kind it does not know.
  factory PendingChange.fromStored({
    required String kind,
    required String deckId,
    required Map<String, dynamic> payload,
  }) => switch (kind) {
    DeckCreated.kindName => DeckCreated(
      deckId: deckId,
      name: payload['name'] as String,
      language: payload['language'] as String,
    ),
    WordAdded.kindName => WordAdded(
      deckId: deckId,
      wordId: payload['word_id'] as String,
      draft: WordDraftJson.fromJson(payload),
    ),
    WordEdited.kindName => WordEdited(
      deckId: deckId,
      wordId: payload['word_id'] as String,
      draft: WordDraftJson.fromJson(payload),
    ),
    WordReviewed.kindName => WordReviewed(
      deckId: deckId,
      wordId: payload['word_id'] as String,
      correct: payload['correct'] as bool,
    ),
    _ => throw FormatException('Unknown pending change "$kind".'),
  };

  /// The deck the change belongs to.
  final String deckId;

  /// Stored next to [payload] to tell the kinds apart.
  String get kind;

  /// Everything but [kind] and [deckId], for storage.
  Map<String, dynamic> get payload;
}

/// `POST /decks` with the id chosen on the device.
final class DeckCreated extends PendingChange {
  const DeckCreated({
    required super.deckId,
    required this.name,
    required this.language,
  });

  static const kindName = 'deck_created';

  final String name;
  final String language;

  @override
  String get kind => kindName;

  @override
  Map<String, dynamic> get payload => {'name': name, 'language': language};

  @override
  List<Object?> get props => [deckId, name, language];
}

/// `POST /decks/{deckId}/words` with the id chosen on the device.
final class WordAdded extends PendingChange {
  const WordAdded({
    required super.deckId,
    required this.wordId,
    required this.draft,
  });

  static const kindName = 'word_added';

  final String wordId;
  final WordDraft draft;

  @override
  String get kind => kindName;

  @override
  Map<String, dynamic> get payload => {'word_id': wordId, ...draft.toJson()};

  @override
  List<Object?> get props => [deckId, wordId, draft];
}

/// `PATCH /words/{wordId}` with all four text fields.
final class WordEdited extends PendingChange {
  const WordEdited({
    required super.deckId,
    required this.wordId,
    required this.draft,
  });

  static const kindName = 'word_edited';

  final String wordId;
  final WordDraft draft;

  @override
  String get kind => kindName;

  @override
  Map<String, dynamic> get payload => {'word_id': wordId, ...draft.toJson()};

  @override
  List<Object?> get props => [deckId, wordId, draft];
}

/// `POST /words/{wordId}/reviews`. Not safe to repeat.
final class WordReviewed extends PendingChange {
  const WordReviewed({
    required super.deckId,
    required this.wordId,
    required this.correct,
  });

  static const kindName = 'word_reviewed';

  final String wordId;
  final bool correct;

  @override
  String get kind => kindName;

  @override
  Map<String, dynamic> get payload => {'word_id': wordId, 'correct': correct};

  @override
  List<Object?> get props => [deckId, wordId, correct];
}

/// A [PendingChange] as stored, with its place in the queue.
class QueuedChange extends Equatable {
  const QueuedChange({
    required this.id,
    required this.change,
    required this.attempts,
  });

  final int id;
  final PendingChange change;

  /// Failed attempts so far.
  final int attempts;

  @override
  List<Object?> get props => [id, change, attempts];
}
