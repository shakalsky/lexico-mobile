import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/usecases/edit_deck.dart';
import 'package:lexico/features/decks/presentation/cubit/edit_deck_cubit.dart';

import '../../../helpers/fake_decks_repository.dart';

void main() {
  late FakeDecksRepository repository;
  // In `Español`.
  final food = testDeckEntity('es-food', name: 'Food');

  EditDeckCubit build() =>
      EditDeckCubit(deck: food, editDeck: EditDeck(repository));

  Deck edited({String name = 'Food', String language = 'Español'}) => Deck(
    id: food.id,
    name: name,
    language: language,
    createdAt: food.createdAt,
  );

  setUp(() => repository = FakeDecksRepository(stored: [food]));

  blocTest<EditDeckCubit, EditDeckState>(
    'saves a trimmed name',
    build: build,
    act: (cubit) => cubit.submit(name: '  Meals ', language: 'Español'),
    expect: () => [
      const EditDeckState(status: EditDeckStatus.saving),
      EditDeckState(
        status: EditDeckStatus.done,
        deck: edited(name: 'Meals'),
      ),
    ],
    verify: (_) => expect(repository.editCalls, [
      (id: 'es-food', name: 'Meals', language: 'Español'),
    ]),
  );

  blocTest<EditDeckCubit, EditDeckState>(
    'saves a new language',
    build: build,
    act: (cubit) => cubit.submit(name: 'Food', language: 'Polski'),
    expect: () => [
      const EditDeckState(status: EditDeckStatus.saving),
      EditDeckState(
        status: EditDeckStatus.done,
        deck: edited(language: 'Polski'),
      ),
    ],
  );

  blocTest<EditDeckCubit, EditDeckState>(
    'changing nothing finishes without saving',
    build: build,
    act: (cubit) => cubit.submit(name: ' Food ', language: 'Español'),
    expect: () => [const EditDeckState(status: EditDeckStatus.done)],
    verify: (_) => expect(repository.editCalls, isEmpty),
  );

  blocTest<EditDeckCubit, EditDeckState>(
    'asks for a name before saving',
    build: build,
    act: (cubit) => cubit.submit(name: '   ', language: 'Polski'),
    expect: () => [const EditDeckState(message: 'Give the deck a name.')],
    verify: (_) => expect(repository.editCalls, isEmpty),
  );

  blocTest<EditDeckCubit, EditDeckState>(
    'shows why saving failed, so the learner can try again',
    setUp: () => repository.editFailure = const CacheFailure('Disk full.'),
    build: build,
    act: (cubit) => cubit.submit(name: 'Meals', language: 'Español'),
    expect: () => [
      const EditDeckState(status: EditDeckStatus.saving),
      const EditDeckState(message: 'Disk full.'),
    ],
  );
}
