import 'package:drift/drift.dart';

/// Every deck the device knows: the service's list, plus decks created here
/// that have not reached it yet.
@DataClassName('DeckRow')
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get language => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Deck content. Owned by the word service and replaced on every sync, except
/// while the deck has changes waiting to be sent.
@DataClassName('WordRow')
class Words extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text()();

  /// Index within the deck, in the order the service returned the words.
  /// Words added on the device go last until the next sync.
  IntColumn get position => integer()();

  /// `null` for a sentence card.
  TextColumn get questionShort => text().nullable()();
  TextColumn get answerShort => text().nullable()();
  TextColumn get questionExample => text()();
  TextColumn get answerExample => text()();

  /// Answer totals as counted by the service, plus answers given on the
  /// device that have not been sent yet.
  IntColumn get showsCount => integer().withDefault(const Constant(0))();
  IntColumn get successesCount => integer().withDefault(const Constant(0))();
  IntColumn get failuresCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Per-word scheduling state. Device-local: a sync must never clobber it.
@DataClassName('ReviewRow')
class Reviews extends Table {
  TextColumn get wordId =>
      text().references(Words, #id, onDelete: KeyAction.cascade)();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  DateTimeColumn get dueAt => dateTime()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  IntColumn get timesSeen => integer().withDefault(const Constant(0))();
  IntColumn get timesCorrect => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {wordId};
}

/// Decks the learner chose to study. Words of other decks stay stored, with
/// their progress, but are left out of sessions and stats.
@DataClassName('StudyDeckRow')
class StudyDecks extends Table {
  TextColumn get deckId => text()();

  @override
  Set<Column<Object>> get primaryKey => {deckId};
}

/// One row per finished sitting — the source of streaks and total XP.
@DataClassName('StudySessionRow')
class StudySessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get reviewedCount => integer()();
  IntColumn get correctCount => integer()();
  IntColumn get xpEarned => integer()();
}

/// Changes made on the device that the word service has not seen yet, sent
/// oldest first.
@DataClassName('PendingChangeRow')
class PendingChanges extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// What kind of change [payload] describes, e.g. `word_added`.
  TextColumn get kind => text()();

  /// The deck the change belongs to. A deck with changes waiting is not
  /// overwritten by a sync.
  TextColumn get deckId => text()();

  /// The change itself, as JSON.
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Failed attempts so far. A change the service keeps refusing is dropped
  /// after a few.
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}
