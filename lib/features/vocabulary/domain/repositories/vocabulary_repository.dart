import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/vocabulary/domain/entities/learner_stats.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:lexico/features/vocabulary/domain/entities/review_state.dart';
import 'package:lexico/features/vocabulary/domain/entities/study_card.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';

/// The domain's view of vocabulary storage. The data layer decides whether an
/// answer comes from the network or the local database.
abstract interface class VocabularyRepository {
  /// Pulls every studied deck from the word service into local storage and
  /// returns how many words are available to study afterwards. Falls back to
  /// what is already stored (or the bundled starter deck) when the network
  /// is unavailable.
  Future<Result<int>> syncDecks();

  /// The ids of the decks the learner studies.
  Future<Result<Set<String>>> studiedDeckIds();

  /// Adds a deck to, or removes it from, the decks being studied. Removing
  /// one keeps its progress for when it is studied again.
  Future<Result<void>> setDeckStudied(String deckId, {required bool studied});

  /// Every word of one deck, in deck order. Comes from the word service,
  /// or from what is stored on the device when the service can't be reached.
  Future<Result<List<VocabWord>>> deckWords(String deckId);

  /// Appends [word] to the end of [deckId] on the word service and returns
  /// it as created. A studied deck is refreshed on the device as well, so
  /// the word can be studied at once.
  Future<Result<VocabWord>> addWord(String deckId, WordDraft word);

  /// Replaces the text of [word] on the word service and returns it as
  /// saved. A stored copy on the device is updated too.
  Future<Result<VocabWord>> editWord(VocabWord word, WordDraft draft);

  /// Cards of the studied decks whose due date has passed, oldest first,
  /// capped at [limit].
  Future<Result<List<StudyCard>>> dueCards({required int limit});

  /// Cards of the studied decks that are not due yet, the soonest first,
  /// capped at [limit]. Used to study ahead once everything due is done.
  Future<Result<List<StudyCard>>> upcomingCards({required int limit});

  /// Stores the new scheduling [state] and reports the answer ([correct] or
  /// not) to the word service. Only the local save can fail the result.
  Future<Result<ReviewState>> saveReview(
    ReviewState state, {
    required bool correct,
  });

  Future<Result<LearnerStats>> learnerStats();

  /// Persists a finished session and returns the streak length it produced.
  Future<Result<int>> logSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int reviewedCount,
    required int correctCount,
    required int xpEarned,
  });
}
