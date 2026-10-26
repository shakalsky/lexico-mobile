import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/vocabulary/domain/entities/learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';

/// The domain's view of vocabulary storage. Offline first: everything is
/// read from and written to the device, and changes reach the word service
/// in the background whenever it can be reached.
abstract interface class VocabularyRepository {
  /// Sends changes made offline, refreshes every studied deck from the word
  /// service where possible, and returns how many words are available to
  /// study afterwards. Without a network it keeps what is stored, or seeds
  /// the bundled starter deck when nothing is.
  Future<Result<int>> syncDecks();

  /// The ids of the decks the learner studies.
  Future<Result<Set<String>>> studiedDeckIds();

  /// Adds a deck to, or removes it from, the decks being studied. Removing
  /// one keeps its progress for when it is studied again.
  Future<Result<void>> setDeckStudied(String deckId, {required bool studied});

  /// Every stored word of one deck, in deck order. Never touches the
  /// network.
  Future<Result<List<VocabWord>>> deckWords(String deckId);

  /// Sends changes made offline, fetches [deckId] from the word service,
  /// stores it and returns its words. A deck with changes the service
  /// hasn't seen yet is returned as stored. Fails when the service can't be
  /// reached, or no longer has the deck.
  Future<Result<List<VocabWord>>> refreshDeckWords(String deckId);

  /// Appends [word] to the end of [deckId] on the device, at once; it
  /// reaches the word service with the next sync.
  Future<Result<VocabWord>> addWord(String deckId, WordDraft word);

  /// Replaces the text of [word] on the device, at once; the change reaches
  /// the word service with the next sync.
  Future<Result<VocabWord>> editWord(VocabWord word, WordDraft draft);

  /// Cards of the studied decks whose due date has passed, oldest first,
  /// capped at [limit].
  Future<Result<List<StudyCard>>> dueCards({required int limit});

  /// Cards of the studied decks that are not due yet, the soonest first,
  /// capped at [limit]. Used to study ahead once everything due is done.
  Future<Result<List<StudyCard>>> upcomingCards({required int limit});

  /// Stores the new scheduling [state], counts the answer ([correct] or
  /// not) and queues it for the word service. Only the local save can fail
  /// the result.
  Future<Result<ReviewState>> saveReview(
    ReviewState state, {
    required bool correct,
  });

  Future<Result<LearnerStats>> learnerStats();

  /// Changes made offline that the word service refused once they were
  /// sent, e.g. a word whose example sentence another device added first.
  /// By the time one arrives, the device already matches the service again.
  Stream<SyncConflict> syncConflicts();

  /// Persists a finished session and returns the streak length it produced.
  Future<Result<int>> logSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int reviewedCount,
    required int correctCount,
    required int xpEarned,
  });
}
