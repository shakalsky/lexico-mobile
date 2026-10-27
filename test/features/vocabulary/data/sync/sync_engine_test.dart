import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/features/decks/data/models/deck_dto.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';
import 'package:lexico/features/vocabulary/data/mappers/vocabulary_mappers.dart';
import 'package:lexico/features/vocabulary/data/models/pending_change.dart';
import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/domain/entities/word_draft.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/offline_harness.dart';

const _draft = WordDraft(
  questionShort: 'el pan',
  answerShort: 'bread',
  questionExample: 'Compro pan cada mañana.',
  answerExample: 'I buy bread every morning.',
);

void main() {
  late OfflineHarness h;

  setUpAll(OfflineHarness.registerFallbacks);

  setUp(() => h = OfflineHarness());

  tearDown(() => h.close());

  Future<void> queue(PendingChange change) => h.pending.add(change, h.now);

  Future<void> storeDeck(String deckId, List<String> wordIds) async {
    await h.decksLocal.addDeck(
      DeckRow(id: deckId, name: deckId, language: 'Español', createdAt: h.now),
    );
    await h.local.replaceDeck(
      deckId,
      deckRows(deckId, [for (final id in wordIds) testDto(id: id)]),
      h.now,
    );
  }

  ServerException refused(String code, [int status = 409]) =>
      ServerException('refused', statusCode: status, code: code);

  group('push', () {
    test('sends every change oldest first, with the ids chosen here', () async {
      h.acceptChanges();
      await queue(
        const DeckCreated(deckId: 'd1', name: 'Food', language: 'Español'),
      );
      await queue(const WordAdded(deckId: 'd1', wordId: 'w1', draft: _draft));
      await queue(const WordEdited(deckId: 'd1', wordId: 'w1', draft: _draft));
      await queue(
        const WordReviewed(deckId: 'd1', wordId: 'w1', correct: false),
      );

      expect(await h.sync.push(), isTrue);

      verifyInOrder([
        () => h.decksRemote.createDeck(
          id: 'd1',
          name: 'Food',
          language: 'Español',
        ),
        () => h.wordsRemote.addWords('d1', [(id: 'w1', draft: _draft)]),
        () => h.wordsRemote.editWord('w1', _draft),
        () => h.wordsRemote.submitReview('w1', correct: false),
      ]);
      expect(await h.pending.count(), 0);
    });

    test('sends a deleted word', () async {
      h.acceptChanges();
      await queue(
        const WordDeleted(deckId: 'd1', wordId: 'w1', subject: 'el pan'),
      );

      expect(await h.sync.push(), isTrue);

      verify(() => h.wordsRemote.deleteWord('w1')).called(1);
      expect(await h.pending.count(), 0);
    });

    test('treats a word already gone as deleted', () async {
      h.acceptChanges();
      when(
        () => h.wordsRemote.deleteWord(any()),
      ).thenThrow(refused('word_not_found', 404));
      final conflicts = <SyncConflict>[];
      h.sync.conflicts.listen(conflicts.add);
      await queue(
        const WordDeleted(deckId: 'd1', wordId: 'w1', subject: 'el pan'),
      );

      expect(await h.sync.push(), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(await h.pending.count(), 0);
      expect(conflicts, isEmpty);
    });

    test('stops at the first change that cannot get through', () async {
      await queue(const WordAdded(deckId: 'd1', wordId: 'w1', draft: _draft));
      await queue(const WordEdited(deckId: 'd1', wordId: 'w1', draft: _draft));

      expect(await h.sync.push(), isFalse);

      verify(() => h.wordsRemote.addWords(any(), any())).called(1);
      verifyNever(() => h.wordsRemote.editWord(any(), any()));
      expect(await h.pending.count(), 2);
    });

    test('treats an id already taken as sent by an earlier try', () async {
      h.acceptChanges();
      when(
        () => h.decksRemote.createDeck(
          id: any(named: 'id'),
          name: any(named: 'name'),
          language: any(named: 'language'),
        ),
      ).thenThrow(refused('deck_id_taken'));
      when(
        () => h.wordsRemote.addWords(any(), any()),
      ).thenThrow(refused('word_ids_taken'));
      await queue(
        const DeckCreated(deckId: 'd1', name: 'Food', language: 'Español'),
      );
      await queue(const WordAdded(deckId: 'd1', wordId: 'w1', draft: _draft));

      expect(await h.sync.push(), isTrue);
      expect(await h.pending.count(), 0);
    });

    test('drops a change the service refuses and goes on', () async {
      h.acceptChanges();
      when(
        () => h.wordsRemote.editWord(any(), any()),
      ).thenThrow(refused('question_example_taken'));
      await queue(const WordEdited(deckId: 'd1', wordId: 'w1', draft: _draft));
      await queue(
        const WordReviewed(deckId: 'd1', wordId: 'w1', correct: true),
      );

      expect(await h.sync.push(), isTrue);

      verify(() => h.wordsRemote.submitReview('w1', correct: true)).called(1);
      expect(await h.pending.count(), 0);
    });

    test('counts an unreadable success reply as sent', () async {
      when(
        () => h.wordsRemote.editWord(any(), any()),
      ).thenThrow(const ServerException('Edit response had no "word".'));
      await queue(const WordEdited(deckId: 'd1', wordId: 'w1', draft: _draft));

      expect(await h.sync.push(), isTrue);
    });

    test('keeps a change the service failed on, up to a limit', () async {
      final limited = OfflineHarness(maxAttempts: 2);
      addTearDown(limited.close);
      when(
        () => limited.wordsRemote.editWord(any(), any()),
      ).thenThrow(const ServerException('boom', statusCode: 500));
      await limited.pending.add(
        const WordEdited(deckId: 'd1', wordId: 'w1', draft: _draft),
        limited.now,
      );

      expect(await limited.sync.push(), isFalse);
      expect((await limited.pending.oldest())!.attempts, 1);

      expect(await limited.sync.push(), isTrue, reason: 'gave up');
      expect(await limited.pending.count(), 0);
    });

    test('never repeats an answer that may have been counted', () async {
      when(
        () => h.wordsRemote.submitReview(any(), correct: any(named: 'correct')),
      ).thenThrow(const NetworkException('timed out', mayHaveArrived: true));
      await queue(
        const WordReviewed(deckId: 'd1', wordId: 'w1', correct: true),
      );

      expect(await h.sync.push(), isTrue);
      expect(await h.pending.count(), 0);
    });

    test('keeps an answer that never left the device', () async {
      await queue(
        const WordReviewed(deckId: 'd1', wordId: 'w1', correct: true),
      );

      expect(await h.sync.push(), isFalse);
      expect(await h.pending.count(), 1);
    });

    test('sends waiting changes as soon as the device is online', () async {
      final network = StreamController<bool>();
      final online = OfflineHarness(onlineChanges: network.stream);
      addTearDown(online.close);
      addTearDown(network.close);
      await online.pending.add(
        const WordEdited(deckId: 'd1', wordId: 'w1', draft: _draft),
        online.now,
      );
      online.acceptChanges();

      network.add(false);
      await pumpEventQueue();
      expect(await online.pending.count(), 1, reason: 'still offline');

      network.add(true);
      await pumpEventQueue();
      await online.sync.push();

      verify(() => online.wordsRemote.editWord('w1', _draft)).called(1);
      expect(await online.pending.count(), 0);
    });

    test('tries again on its own once the service is back', () async {
      final retrying = OfflineHarness(
        retryDelays: const [Duration(milliseconds: 20)],
      );
      addTearDown(retrying.close);
      await retrying.pending.add(
        const WordEdited(deckId: 'd1', wordId: 'w1', draft: _draft),
        retrying.now,
      );

      expect(await retrying.sync.push(), isFalse);
      retrying.acceptChanges();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(await retrying.pending.count(), 0);
    });
  });

  group('conflicts', () {
    late List<SyncConflict> conflicts;

    setUp(() {
      conflicts = [];
      h.sync.conflicts.listen(conflicts.add);
      h.acceptChanges();
    });

    test('an edit the service refuses is undone and reported', () async {
      await storeDeck('d1', ['w1']);
      await queue(const WordEdited(deckId: 'd1', wordId: 'w1', draft: _draft));
      when(
        () => h.wordsRemote.editWord(any(), any()),
      ).thenThrow(refused('question_example_taken'));
      when(
        () => h.wordsRemote.fetchWords('d1'),
      ).thenAnswer((_) async => [testDto(id: 'w1', question: 'del servidor')]);

      await h.sync.push();
      await pumpEventQueue();

      final word = (await h.local.wordsOfDeck('d1')).single;
      expect(word.questionShort, 'del servidor');
      expect(conflicts, [
        const SyncConflict(
          change: SyncedChange.wordEdited,
          reason: SyncConflictReason.duplicateExample,
          deckId: 'd1',
          subject: 'el pan',
          serverMessage: 'refused',
        ),
      ]);
    });

    test('a word the service refuses is removed and reported', () async {
      await storeDeck('d1', ['w1']);
      await h.local.insertWord(
        WordRow(
          id: 'w2',
          deckId: 'd1',
          position: 1,
          questionShort: _draft.questionShort,
          answerShort: _draft.answerShort,
          questionExample: _draft.questionExample,
          answerExample: _draft.answerExample,
          showsCount: 0,
          successesCount: 0,
          failuresCount: 0,
        ),
        h.now,
      );
      await queue(const WordAdded(deckId: 'd1', wordId: 'w2', draft: _draft));
      when(
        () => h.wordsRemote.addWords(any(), any()),
      ).thenThrow(refused('question_examples_taken'));
      when(
        () => h.wordsRemote.fetchWords('d1'),
      ).thenAnswer((_) async => [testDto(id: 'w1')]);

      await h.sync.push();
      await pumpEventQueue();

      expect((await h.local.wordsOfDeck('d1')).map((w) => w.id), ['w1']);
      expect(conflicts.single.change, SyncedChange.wordAdded);
      expect(conflicts.single.reason, SyncConflictReason.duplicateExample);
    });

    test('a word added to a deleted deck reports the deck gone', () async {
      await queue(const WordAdded(deckId: 'd1', wordId: 'w2', draft: _draft));
      when(
        () => h.wordsRemote.addWords(any(), any()),
      ).thenThrow(refused('deck_not_found', 404));

      await h.sync.push();
      await pumpEventQueue();

      expect(conflicts.single.reason, SyncConflictReason.deckGone);
    });

    void refuseDeckEdits(ServerException error) => when(
      () => h.decksRemote.editDeck(
        any(),
        name: any(named: 'name'),
        language: any(named: 'language'),
      ),
    ).thenThrow(error);

    test('a deck edit the service refuses is undone and reported', () async {
      await storeDeck('d1', ['w1']);
      await h.decksLocal.editDeck('d1', name: 'Mine', language: 'Polski');
      await queue(
        const DeckEdited(
          deckId: 'd1',
          deckName: 'Mine',
          name: 'Mine',
          language: 'Polski',
        ),
      );
      refuseDeckEdits(refused('FST_ERR_VALIDATION', 400));
      when(h.decksRemote.fetchDecks).thenAnswer(
        (_) async => [
          DeckDto(
            id: 'd1',
            name: 'Theirs',
            language: 'Español',
            createdAt: h.now,
          ),
        ],
      );

      await h.sync.push();
      await pumpEventQueue();

      final deck = (await h.decksLocal.decks()).single;
      expect(deck.name, 'Theirs');
      expect(deck.language, 'Español');
      expect(await h.local.wordsOfDeck('d1'), hasLength(1));
      expect(conflicts, [
        const SyncConflict(
          change: SyncedChange.deckEdited,
          reason: SyncConflictReason.refused,
          deckId: 'd1',
          subject: 'Mine',
          serverMessage: 'refused',
        ),
      ]);
    });

    test('editing a deck deleted on the service removes it', () async {
      await storeDeck('d1', ['w1']);
      await queue(
        const DeckEdited(deckId: 'd1', deckName: 'd1', language: 'Polski'),
      );
      refuseDeckEdits(refused('deck_not_found', 404));
      when(h.decksRemote.fetchDecks).thenAnswer((_) async => []);

      await h.sync.push();
      await pumpEventQueue();

      expect(await h.decksLocal.deckIds(), isEmpty);
      expect(conflicts.single.reason, SyncConflictReason.deckGone);
    });

    test('a refused answer is not reported', () async {
      await queue(
        const WordReviewed(deckId: 'd1', wordId: 'w1', correct: true),
      );
      when(
        () => h.wordsRemote.submitReview(any(), correct: any(named: 'correct')),
      ).thenThrow(refused('word_not_found', 404));

      await h.sync.push();
      await pumpEventQueue();

      expect(conflicts, isEmpty);
    });
  });

  group('refreshDecks', () {
    DeckDto deck(String id) =>
        DeckDto(id: id, name: id, language: 'Español', createdAt: h.now);

    test(
      'stores the service list and forgets decks it no longer has',
      () async {
        await storeDeck('gone', ['g1']);
        await h.local.setDeckStudied('gone', studied: true);
        when(h.decksRemote.fetchDecks).thenAnswer((_) async => [deck('d1')]);

        await h.sync.refreshDecks();

        expect(await h.decksLocal.deckIds(), {'d1'});
        expect(await h.local.wordsOfDeck('gone'), isEmpty);
        expect(await h.local.studiedDeckIds(), isNot(contains('gone')));
      },
    );

    test('keeps a deck created here that has not been sent yet', () async {
      when(
        () => h.decksRemote.createDeck(
          id: any(named: 'id'),
          name: any(named: 'name'),
          language: any(named: 'language'),
        ),
      ).thenThrow(const ServerException('boom', statusCode: 500));
      await storeDeck('mine', []);
      await queue(
        const DeckCreated(deckId: 'mine', name: 'Mine', language: 'Español'),
      );
      when(h.decksRemote.fetchDecks).thenAnswer((_) async => [deck('d1')]);

      await h.sync.refreshDecks();

      expect(await h.decksLocal.deckIds(), {'d1', 'mine'});
    });

    test('fails when the service cannot be reached', () async {
      await expectLater(
        h.sync.refreshDecks(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('refreshDeck', () {
    test('sends waiting changes, then stores the service copy', () async {
      h.acceptChanges();
      await storeDeck('d1', ['w1']);
      await queue(const WordEdited(deckId: 'd1', wordId: 'w1', draft: _draft));
      when(
        () => h.wordsRemote.fetchWords('d1'),
      ).thenAnswer((_) async => [testDto(id: 'w1'), testDto(id: 'w2')]);

      await h.sync.refreshDeck('d1');

      verifyInOrder([
        () => h.wordsRemote.editWord('w1', _draft),
        () => h.wordsRemote.fetchWords('d1'),
      ]);
      final words = await h.local.wordsOfDeck('d1');
      expect(words.map((w) => w.id), ['w1', 'w2']);
    });

    test('leaves a deck with unsent changes as it is', () async {
      await storeDeck('d1', ['w1']);
      await queue(const WordAdded(deckId: 'd1', wordId: 'w9', draft: _draft));

      await h.sync.refreshDeck('d1');

      verifyNever(() => h.wordsRemote.fetchWords(any()));
      expect(await h.local.wordsOfDeck('d1'), hasLength(1));
    });

    test('removes a deck the service no longer has', () async {
      await storeDeck('d1', ['w1']);
      when(() => h.wordsRemote.fetchWords('d1')).thenThrow(
        const ServerException(
          'No deck.',
          statusCode: 404,
          code: 'deck_not_found',
        ),
      );

      await expectLater(
        h.sync.refreshDeck('d1'),
        throwsA(isA<ServerException>()),
      );

      expect(await h.local.wordsOfDeck('d1'), isEmpty);
      expect(await h.decksLocal.deckIds(), isEmpty);
    });

    test('keeps the stored words when the service sends none', () async {
      await storeDeck('d1', ['w1']);
      when(() => h.wordsRemote.fetchWords('d1')).thenAnswer((_) async => []);

      await h.sync.refreshDeck('d1');

      expect(await h.local.wordsOfDeck('d1'), hasLength(1));
    });
  });

  group('refreshStudiedDecks', () {
    setUp(() async {
      await h.local.setDeckStudied('a', studied: true);
      await h.local.setDeckStudied('b', studied: true);
    });

    test('stops trying once the service is unreachable', () async {
      await h.sync.refreshStudiedDecks();

      // es-en-core is studied on a fresh install too.
      verify(() => h.wordsRemote.fetchWords(any())).called(1);
    });

    test('goes on after a deck the service failed on', () async {
      when(
        () => h.wordsRemote.fetchWords(any()),
      ).thenThrow(const ServerException('boom', statusCode: 500));

      await h.sync.refreshStudiedDecks();

      verify(() => h.wordsRemote.fetchWords(any())).called(3);
    });
  });
}
