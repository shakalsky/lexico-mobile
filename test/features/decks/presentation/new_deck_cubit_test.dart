import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/decks/domain/entities/deck_language.dart';
import 'package:lexico/features/decks/domain/usecases/create_deck.dart';
import 'package:lexico/features/decks/presentation/cubit/new_deck_cubit.dart';

import '../../../helpers/fake_decks_repository.dart';

void main() {
  late FakeDecksRepository repository;
  final food = testDeckEntity('generated-id', name: 'Food');

  NewDeckCubit build() => NewDeckCubit(createDeck: CreateDeck(repository));

  blocTest<NewDeckCubit, NewDeckState>(
    'creates the deck with a trimmed name and the language label',
    setUp: () =>
        repository = FakeDecksRepository(created: [Result.success(food)]),
    build: build,
    act: (cubit) =>
        cubit.submit(name: '  Food ', language: DeckLanguage.polish),
    expect: () => [
      const NewDeckState(status: NewDeckStatus.saving),
      NewDeckState(status: NewDeckStatus.created, deck: food),
    ],
    verify: (_) =>
        expect(repository.createCalls, [(name: 'Food', language: 'Polski')]),
  );

  blocTest<NewDeckCubit, NewDeckState>(
    'asks for a name before calling the service',
    setUp: () => repository = FakeDecksRepository(),
    build: build,
    act: (cubit) => cubit.submit(name: '   ', language: DeckLanguage.english),
    expect: () => [const NewDeckState(message: 'Give the deck a name.')],
    verify: (_) => expect(repository.createCalls, isEmpty),
  );

  blocTest<NewDeckCubit, NewDeckState>(
    'shows why the service refused, so the learner can try again',
    setUp: () => repository = FakeDecksRepository(
      created: [const Result.failure(NetworkFailure('No connection.'))],
    ),
    build: build,
    act: (cubit) => cubit.submit(name: 'Food', language: DeckLanguage.english),
    expect: () => [
      const NewDeckState(status: NewDeckStatus.saving),
      const NewDeckState(message: 'No connection.'),
    ],
  );
}
