import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/exception.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/features/decks/data/models/deck_dto.dart';
import 'package:lexico/features/decks/data/repositories/decks_repository_impl.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/vocabulary/data/mappers/vocabulary_mappers.dart';
import 'package:lexico/features/vocabulary/data/models/pending_change.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/offline_harness.dart';

void main() {
  late OfflineHarness h;
  late DecksRepositoryImpl repository;

  setUpAll(OfflineHarness.registerFallbacks);

  setUp(() {
    h = OfflineHarness();
    repository = DecksRepositoryImpl(
      local: h.decksLocal,
      words: h.local,
      pending: h.pending,
      transaction: h.transaction,
      sync: h.sync,
      clock: () => h.now,
      newId: () => 'new-deck',
    );
  });

  tearDown(() => h.close());

  DeckDto dto(String id, int day) => DeckDto(
    id: id,
    name: id,
    language: 'Español',
    createdAt: DateTime(2026, 10, day),
  );

  test('creates a deck on the device at once, even offline', () async {
    final deck = (await repository.createDeck(
      name: 'Food',
      language: 'Español',
    )).valueOrNull!;

    expect(deck.id, 'new-deck');
    expect(deck.name, 'Food');
    expect((await repository.getDecks()).valueOrNull, [deck]);
    expect(
      (await h.pending.oldest())!.change,
      const DeckCreated(deckId: 'new-deck', name: 'Food', language: 'Español'),
    );
  });

  test('sends a new deck to the service with its id', () async {
    h.acceptChanges();

    await repository.createDeck(name: 'Food', language: 'Español');
    await h.sync.push();

    verify(
      () => h.decksRemote.createDeck(
        id: 'new-deck',
        name: 'Food',
        language: 'Español',
      ),
    ).called(1);
    expect(await h.pending.count(), 0);
  });

  test('reads stored decks oldest first, without the network', () async {
    when(
      h.decksRemote.fetchDecks,
    ).thenAnswer((_) async => [dto('b', 9), dto('a', 8)]);
    await repository.refreshDecks();
    clearInteractions(h.decksRemote);

    final decks = (await repository.getDecks()).valueOrNull!;

    expect(decks.map((d) => d.id), ['a', 'b']);
    verifyZeroInteractions(h.decksRemote);
  });

  test('a refresh stores and returns the service list', () async {
    when(h.decksRemote.fetchDecks).thenAnswer((_) async => [dto('a', 8)]);

    final decks = (await repository.refreshDecks()).valueOrNull!;

    expect(decks.single.id, 'a');
  });

  test('a refresh offline fails and keeps what is stored', () async {
    await repository.createDeck(name: 'Food', language: 'Español');

    final result = await repository.refreshDecks();

    expect(result.failureOrNull, const NetworkFailure('offline'));
    expect((await repository.getDecks()).valueOrNull, hasLength(1));
  });

  group('deleteDeck', () {
    /// A synced, studied deck with two words, and a change waiting for it.
    Future<Deck> storeDeck() async {
      when(h.decksRemote.fetchDecks).thenAnswer((_) async => [dto('d1', 8)]);
      await repository.refreshDecks();
      await h.local.replaceDeck(
        'd1',
        deckRows('d1', [testDto(id: 'w1'), testDto(id: 'w2')]),
        h.now,
      );
      await h.local.setDeckStudied('d1', studied: true);
      await h.pending.add(
        const WordReviewed(deckId: 'd1', wordId: 'w1', correct: true),
        h.now,
      );
      reset(h.decksRemote);
      return (await repository.getDecks()).valueOrNull!.single;
    }

    test('removes the deck, its words and waiting changes at once', () async {
      final deck = await storeDeck();

      final result = await repository.deleteDeck(deck);

      expect(result.isSuccess, isTrue);
      expect((await repository.getDecks()).valueOrNull, isEmpty);
      expect(await h.local.wordsOfDeck('d1'), isEmpty);
      expect(await h.db.select(h.db.reviews).get(), isEmpty);
      expect(await h.local.studiedDeckIds(), isNot(contains('d1')));
      expect(await h.pending.count(), 1);
      expect(
        (await h.pending.oldest())!.change,
        const DeckDeleted(deckId: 'd1', name: 'd1'),
      );
    });

    test('sends the deletion to the service', () async {
      final deck = await storeDeck();
      h.acceptChanges();

      await repository.deleteDeck(deck);
      await h.sync.push();

      verify(() => h.decksRemote.deleteDeck('d1')).called(1);
      verifyNever(
        () => h.wordsRemote.submitReview(any(), correct: any(named: 'correct')),
      );
      expect(await h.pending.count(), 0);
    });

    test('a deck already gone counts as deleted', () async {
      final deck = await storeDeck();
      h.acceptChanges();
      when(() => h.decksRemote.deleteDeck(any())).thenThrow(
        const ServerException(
          'No deck.',
          statusCode: 404,
          code: 'deck_not_found',
        ),
      );

      await repository.deleteDeck(deck);

      expect(await h.sync.push(), isTrue);
      expect(await h.pending.count(), 0);
    });

    test(
      'stays deleted when a refresh runs before the service hears of it',
      () async {
        final deck = await storeDeck();
        when(
          () => h.decksRemote.deleteDeck(any()),
        ).thenThrow(const ServerException('Down.', statusCode: 503));
        when(h.decksRemote.fetchDecks).thenAnswer((_) async => [dto('d1', 8)]);

        await repository.deleteDeck(deck);
        final decks = (await repository.refreshDecks()).valueOrNull!;

        expect(decks, isEmpty);
        expect(await h.pending.count(), 1);
      },
    );
  });
}
