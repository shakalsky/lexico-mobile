import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/usecases/get_decks.dart';
import 'package:lexico/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_studied_deck_ids.dart';
import 'package:lexico/features/vocabulary/domain/usecases/set_deck_studied.dart';

import '../../../helpers/fake_decks_repository.dart';
import '../../../helpers/fake_vocabulary_repository.dart';

final _core = testDeckEntity('es-en-core', name: 'Core');
final _food = testDeckEntity('es-food', name: 'Food', day: 9);

void main() {
  late FakeVocabularyRepository vocabulary;

  setUp(() => vocabulary = FakeVocabularyRepository());

  DecksBloc bloc(List<Result<List<Deck>>> results) => DecksBloc(
    getDecks: GetDecks(FakeDecksRepository(decks: results)),
    getStudiedDeckIds: GetStudiedDeckIds(vocabulary),
    setDeckStudied: SetDeckStudied(vocabulary),
  );

  DecksState ready(List<Deck> decks, {Set<String> studied = const {}}) =>
      DecksState(status: DecksStatus.ready, decks: decks, studiedIds: studied);

  group('loading', () {
    blocTest<DecksBloc, DecksState>(
      'loads the list and which decks are studied',
      build: () => bloc([
        Result.success([_core, _food]),
      ]),
      act: (bloc) => bloc.add(const DecksRequested()),
      expect: () => [
        const DecksState(status: DecksStatus.loading),
        ready([_core, _food], studied: {'es-en-core'}),
      ],
    );

    blocTest<DecksBloc, DecksState>(
      'reports a failed load',
      build: () => bloc([const Result.failure(NetworkFailure('offline'))]),
      act: (bloc) => bloc.add(const DecksRequested()),
      expect: () => [
        const DecksState(status: DecksStatus.loading),
        const DecksState(status: DecksStatus.failure, message: 'offline'),
      ],
    );
  });

  group('refreshing', () {
    blocTest<DecksBloc, DecksState>(
      'replaces the list without a spinner',
      build: () => bloc([
        Result.success([_core, _food]),
      ]),
      seed: () => ready([_core]),
      act: (bloc) => bloc.add(const DecksRefreshed()),
      expect: () => [
        ready([_core, _food], studied: {'es-en-core'}),
      ],
    );

    blocTest<DecksBloc, DecksState>(
      'a failure keeps the list and reports why',
      build: () => bloc([const Result.failure(NetworkFailure('offline'))]),
      seed: () => ready([_core]),
      act: (bloc) => bloc.add(const DecksRefreshed()),
      expect: () => [
        ready([_core]).copyWith(notice: "Couldn't refresh: offline"),
      ],
    );

    blocTest<DecksBloc, DecksState>(
      'after a failed load does a full load',
      build: () => bloc([
        Result.success([_core]),
      ]),
      seed: () => const DecksState(status: DecksStatus.failure, message: 'x'),
      act: (bloc) => bloc.add(const DecksRefreshed()),
      expect: () => [
        const DecksState(status: DecksStatus.loading),
        ready([_core], studied: {'es-en-core'}),
      ],
    );

    test('signals when it is done, even if nothing changed', () async {
      final decksBloc = bloc([
        Result.success([_core]),
      ])..emit(ready([_core], studied: {'es-en-core'}));

      final done = Completer<void>();
      decksBloc.add(DecksRefreshed(done));

      await expectLater(done.future, completes);
      await decksBloc.close();
    });
  });

  group('adding', () {
    blocTest<DecksBloc, DecksState>(
      'a new deck goes at the end of the list',
      build: () => bloc([]),
      seed: () => ready([_core]),
      act: (bloc) => bloc.add(DeckAdded(_food)),
      expect: () => [
        ready([_core, _food]),
      ],
    );

    blocTest<DecksBloc, DecksState>(
      'with no list on screen reloads everything',
      build: () => bloc([
        Result.success([_core, _food]),
      ]),
      seed: () => const DecksState(status: DecksStatus.failure, message: 'x'),
      act: (bloc) => bloc.add(DeckAdded(_food)),
      expect: () => [
        const DecksState(status: DecksStatus.loading),
        ready([_core, _food], studied: {'es-en-core'}),
      ],
    );
  });

  group('study switch', () {
    blocTest<DecksBloc, DecksState>(
      'turns a deck on at once, then saves it',
      build: () => bloc([]),
      seed: () => ready([_core, _food], studied: {'es-en-core'}),
      act: (bloc) => bloc.add(const DeckStudyToggled('es-food')),
      expect: () => [
        ready(
          [_core, _food],
          studied: {'es-en-core', 'es-food'},
        ).copyWith(pendingIds: {'es-food'}),
        ready([_core, _food], studied: {'es-en-core', 'es-food'}),
      ],
      verify: (_) => expect(vocabulary.studiedIds, {'es-en-core', 'es-food'}),
    );

    blocTest<DecksBloc, DecksState>(
      'turns a studied deck off',
      build: () => bloc([]),
      seed: () => ready([_core], studied: {'es-en-core'}),
      act: (bloc) => bloc.add(const DeckStudyToggled('es-en-core')),
      expect: () => [
        ready([_core]).copyWith(pendingIds: {'es-en-core'}),
        ready([_core]),
      ],
      verify: (_) => expect(vocabulary.studiedIds, isEmpty),
    );

    blocTest<DecksBloc, DecksState>(
      'flips back and explains when the save fails',
      build: () {
        vocabulary.setStudiedFailure = const CacheFailure('disk full');
        return bloc([]);
      },
      seed: () => ready([_core, _food], studied: {'es-en-core'}),
      act: (bloc) => bloc.add(const DeckStudyToggled('es-food')),
      expect: () => [
        ready(
          [_core, _food],
          studied: {'es-en-core', 'es-food'},
        ).copyWith(pendingIds: {'es-food'}),
        ready(
          [_core, _food],
          studied: {'es-en-core'},
        ).copyWith(notice: "Couldn't save: disk full"),
      ],
    );

    blocTest<DecksBloc, DecksState>(
      'ignores taps while the deck is still saving',
      build: () => bloc([]),
      seed: () => ready([_food]).copyWith(pendingIds: {'es-food'}),
      act: (bloc) => bloc.add(const DeckStudyToggled('es-food')),
      expect: () => <DecksState>[],
    );
  });
}
