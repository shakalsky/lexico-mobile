import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/decks/presentation/cubit/deck_words_cubit.dart';
import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/domain/entities/vocab_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/delete_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/refresh_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/watch_sync_conflicts.dart';

import '../../../helpers/fake_vocabulary_repository.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late FakeVocabularyRepository vocabulary;

  final stored = [testWord(id: 'a')];
  final fresh = [testWord(id: 'a'), testWord(id: 'b')];

  setUp(() => vocabulary = FakeVocabularyRepository());

  DeckWordsCubit cubit({
    List<VocabWord> storedWords = const [],
    required Result<List<VocabWord>> refreshed,
  }) {
    vocabulary.storedDeckWords[testDeckId] = storedWords;
    vocabulary.deckWordResults[testDeckId] = [refreshed];
    return DeckWordsCubit(
      deckId: testDeckId,
      getDeckWords: GetDeckWords(vocabulary),
      refreshDeckWords: RefreshDeckWords(vocabulary),
      watchSyncConflicts: WatchSyncConflicts(vocabulary),
      deleteWord: DeleteWord(vocabulary),
    );
  }

  DeckWordsState ready(List<VocabWord> words) =>
      DeckWordsState(status: DeckWordsStatus.ready, words: words);

  blocTest<DeckWordsCubit, DeckWordsState>(
    'shows the stored words first, then the refreshed ones',
    build: () => cubit(storedWords: stored, refreshed: Result.success(fresh)),
    act: (cubit) => cubit.load(),
    expect: () => [const DeckWordsState(), ready(stored), ready(fresh)],
  );

  blocTest<DeckWordsCubit, DeckWordsState>(
    'keeps the stored words quietly when offline',
    build: () => cubit(
      storedWords: stored,
      refreshed: const Result.failure(NetworkFailure('offline')),
    ),
    act: (cubit) => cubit.load(),
    expect: () => [const DeckWordsState(), ready(stored)],
  );

  blocTest<DeckWordsCubit, DeckWordsState>(
    'reports the problem when nothing is stored',
    build: () =>
        cubit(refreshed: const Result.failure(NetworkFailure('offline'))),
    act: (cubit) => cubit.load(),
    expect: () => [
      const DeckWordsState(),
      const DeckWordsState(status: DeckWordsStatus.failure, message: 'offline'),
    ],
  );

  blocTest<DeckWordsCubit, DeckWordsState>(
    'drops the stored words of a deck that no longer exists',
    build: () => cubit(
      storedWords: stored,
      refreshed: const Result.failure(
        ServerFailure('No deck.', statusCode: 404, code: 'deck_not_found'),
      ),
    ),
    act: (cubit) => cubit.load(),
    expect: () => [
      const DeckWordsState(),
      ready(stored),
      const DeckWordsState(
        status: DeckWordsStatus.failure,
        message: 'No deck.',
      ),
    ],
  );

  group('deleteWord', () {
    blocTest<DeckWordsCubit, DeckWordsState>(
      'takes the word off the list',
      build: () => cubit(refreshed: Result.success(fresh)),
      seed: () => ready(fresh),
      act: (cubit) => cubit.deleteWord(fresh.first),
      expect: () => [
        ready([fresh.last]),
      ],
      verify: (_) => expect(vocabulary.deletedWords, [fresh.first]),
    );

    blocTest<DeckWordsCubit, DeckWordsState>(
      'puts it back in its place when the delete fails',
      build: () {
        vocabulary.deleteWordFailure = const CacheFailure('disk full');
        return cubit(refreshed: Result.success(fresh));
      },
      seed: () => ready(fresh),
      act: (cubit) => cubit.deleteWord(fresh.first),
      expect: () => [
        ready([fresh.last]),
        DeckWordsState(
          status: DeckWordsStatus.ready,
          words: fresh,
          notice: "Couldn't delete “${fresh.first.question}”: disk full",
        ),
      ],
    );
  });

  group('after a refused change', () {
    SyncConflict conflict(
      SyncConflictReason reason, {
      String deckId = testDeckId,
    }) => SyncConflict(
      change: SyncedChange.wordAdded,
      reason: reason,
      deckId: deckId,
      subject: 'el pan',
      serverMessage: 'refused',
    );

    blocTest<DeckWordsCubit, DeckWordsState>(
      'shows the stored words as they are now',
      build: () => cubit(refreshed: Result.success(fresh)),
      seed: () => ready(fresh),
      act: (cubit) {
        vocabulary.storedDeckWords[testDeckId] = stored;
        vocabulary.conflicts.add(conflict(SyncConflictReason.duplicateExample));
      },
      expect: () => [ready(stored)],
    );

    blocTest<DeckWordsCubit, DeckWordsState>(
      'ignores conflicts of other decks',
      build: () => cubit(refreshed: Result.success(fresh)),
      seed: () => ready(fresh),
      act: (cubit) => vocabulary.conflicts.add(
        conflict(SyncConflictReason.duplicateExample, deckId: 'other'),
      ),
      expect: () => <DeckWordsState>[],
    );

    blocTest<DeckWordsCubit, DeckWordsState>(
      'says so when the deck itself is gone',
      build: () => cubit(refreshed: Result.success(fresh)),
      seed: () => ready(fresh),
      act: (cubit) =>
          vocabulary.conflicts.add(conflict(SyncConflictReason.deckGone)),
      expect: () => [
        const DeckWordsState(
          status: DeckWordsStatus.failure,
          message: 'This deck no longer exists.',
        ),
      ],
    );
  });
}
