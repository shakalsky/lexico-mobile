import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/features/decks/data/models/deck_dto.dart';
import 'package:lexico/features/decks/data/repositories/decks_repository_impl.dart';
import 'package:lexico/features/vocabulary/data/models/pending_change.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/offline_harness.dart';

void main() {
  late OfflineHarness h;
  late DecksRepositoryImpl repository;

  setUpAll(OfflineHarness.registerFallbacks);

  setUp(() {
    h = OfflineHarness();
    repository = DecksRepositoryImpl(
      local: h.decksLocal,
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
}
