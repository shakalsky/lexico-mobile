import 'package:drift/native.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/features/decks/data/datasources/decks_local_data_source.dart';
import 'package:lexico/features/decks/data/datasources/decks_remote_data_source.dart';
import 'package:lexico/features/decks/data/models/deck_dto.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/local_transaction.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/pending_changes_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/vocabulary_local_data_source.dart';
import 'package:lexico/features/vocabulary/data/datasources/remote/vocabulary_remote_data_source.dart';
import 'package:lexico/features/vocabulary/data/sync/sync_engine.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:mocktail/mocktail.dart';

import 'fixtures.dart';

class MockWordsRemote extends Mock implements VocabularyRemoteDataSource {}

class MockDecksRemote extends Mock implements DecksRemoteDataSource {}

/// The real data layer on an in-memory database, with only the word service
/// mocked. Every remote call fails as offline until a test says otherwise.
class OfflineHarness {
  OfflineHarness({
    DateTime? now,
    List<Duration> retryDelays = const [],
    int maxAttempts = 5,
    Stream<bool> onlineChanges = const Stream.empty(),
  }) : now = now ?? DateTime(2026, 8, 21, 10) {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = VocabularyLocalDataSourceImpl(db);
    decksLocal = DecksLocalDataSourceImpl(db);
    pending = PendingChangesLocalDataSourceImpl(db);
    transaction = LocalTransaction(db);
    sync = SyncEngine(
      wordsRemote: wordsRemote,
      decksRemote: decksRemote,
      local: local,
      decksLocal: decksLocal,
      pending: pending,
      transaction: transaction,
      clock: () => this.now,
      retryDelays: retryDelays,
      maxAttempts: maxAttempts,
      onlineChanges: onlineChanges,
    );
    goOffline();
  }

  /// Call once from `setUpAll` in every file that uses the harness.
  static void registerFallbacks() {
    registerFallbackValue(<({String id, WordDraft draft})>[]);
    registerFallbackValue(
      const WordDraft(questionExample: '', answerExample: ''),
    );
  }

  DateTime now;
  final MockWordsRemote wordsRemote = MockWordsRemote();
  final MockDecksRemote decksRemote = MockDecksRemote();
  late final AppDatabase db;
  late final VocabularyLocalDataSourceImpl local;
  late final DecksLocalDataSourceImpl decksLocal;
  late final PendingChangesLocalDataSourceImpl pending;
  late final LocalTransaction transaction;
  late final SyncEngine sync;

  /// Every call to the word service fails before it leaves the device.
  void goOffline() {
    const offline = NetworkException('offline');
    when(() => wordsRemote.fetchWords(any())).thenThrow(offline);
    when(() => wordsRemote.addWords(any(), any())).thenThrow(offline);
    when(() => wordsRemote.editWord(any(), any())).thenThrow(offline);
    when(
      () => wordsRemote.submitReview(any(), correct: any(named: 'correct')),
    ).thenThrow(offline);
    when(decksRemote.fetchDecks).thenThrow(offline);
    when(
      () => decksRemote.createDeck(
        id: any(named: 'id'),
        name: any(named: 'name'),
        language: any(named: 'language'),
      ),
    ).thenThrow(offline);
    when(
      () => decksRemote.editDeck(
        any(),
        name: any(named: 'name'),
        language: any(named: 'language'),
      ),
    ).thenThrow(offline);
  }

  /// Every change is accepted; fetches still need stubbing per test.
  void acceptChanges() {
    // The sync engine doesn't read the replies of accepted changes.
    when(
      () => wordsRemote.addWords(any(), any()),
    ).thenAnswer((_) async => [testDto()]);
    when(
      () => wordsRemote.editWord(any(), any()),
    ).thenAnswer((_) async => testDto());
    when(() => wordsRemote.deleteWord(any())).thenAnswer((_) async {});
    when(() => decksRemote.deleteDeck(any())).thenAnswer((_) async {});
    when(
      () => decksRemote.editDeck(
        any(),
        name: any(named: 'name'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (invocation) async => DeckDto(
        id: invocation.positionalArguments[0] as String,
        name: invocation.namedArguments[#name] as String? ?? 'unchanged',
        language: invocation.namedArguments[#language] as String? ?? 'Español',
        createdAt: now,
      ),
    );
    when(
      () => wordsRemote.submitReview(any(), correct: any(named: 'correct')),
    ).thenAnswer((_) async => testDto());
    when(
      () => decksRemote.createDeck(
        id: any(named: 'id'),
        name: any(named: 'name'),
        language: any(named: 'language'),
      ),
    ).thenAnswer(
      (invocation) async => DeckDto(
        id: invocation.namedArguments[#id] as String,
        name: invocation.namedArguments[#name] as String,
        language: invocation.namedArguments[#language] as String,
        createdAt: now,
      ),
    );
  }

  Future<void> close() async {
    sync.dispose();
    await db.close();
  }
}
