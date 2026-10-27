import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/usecases/delete_deck.dart';
import 'package:lexico/features/decks/domain/usecases/get_decks.dart';
import 'package:lexico/features/decks/domain/usecases/refresh_decks.dart';
import 'package:lexico/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_studied_deck_ids.dart';
import 'package:lexico/features/vocabulary/domain/usecases/set_deck_studied.dart';

import '../../../helpers/fake_decks_repository.dart';
import '../../../helpers/fake_vocabulary_repository.dart';

final _core = testDeckEntity('es-en-core', name: 'Core');
final _food = testDeckEntity('es-food', name: 'Food', day: 9);

void main() {
  late FakeVocabularyRepository vocabulary;
  late FakeDecksRepository decks;

  setUp(() => vocabulary = FakeVocabularyRepository());

  DecksBloc bloc(
    List<Result<List<Deck>>> results, {
    List<Deck> stored = const [],
  }) {
    decks = FakeDecksRepository(decks: results, stored: stored);
    return DecksBloc(
      getDecks: GetDecks(decks),
      refreshDecks: RefreshDecks(decks),
      getStudiedDeckIds: GetStudiedDeckIds(vocabulary),
      setDeckStudied: SetDeckStudied(vocabulary),
      deleteDeck: DeleteDeck(decks),
    );
  }

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
      'shows the stored decks first, then the refreshed list',
      build: () => bloc(
        [
          Result.success([_core, _food]),
        ],
        stored: [_core],
      ),
      act: (bloc) => bloc.add(const DecksRequested()),
      expect: () => [
        const DecksState(status: DecksStatus.loading),
        ready([_core], studied: {'es-en-core'}),
        ready([_core, _food], studied: {'es-en-core'}),
      ],
    );

    blocTest<DecksBloc, DecksState>(
      'keeps the stored decks quietly when offline',
      build: () => bloc(
        [const Result.failure(NetworkFailure('offline'))],
        stored: [_core],
      ),
      act: (bloc) => bloc.add(const DecksRequested()),
      expect: () => [
        const DecksState(status: DecksStatus.loading),
        ready([_core], studied: {'es-en-core'}),
      ],
    );

    blocTest<DecksBloc, DecksState>(
      'reports a failed load when nothing is stored',
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

  group('deleting', () {
    blocTest<DecksBloc, DecksState>(
      'takes the deck off the list and out of the study rotation',
      build: () => bloc([]),
      seed: () => ready([_core, _food], studied: {'es-en-core', 'es-food'}),
      act: (bloc) async {
        final done = Completer<bool>();
        bloc.add(DeckDeleteConfirmed(_food, done));
        expect(await done.future, isTrue);
      },
      expect: () => [
        ready([_core], studied: {'es-en-core'}),
      ],
      verify: (_) => expect(decks.deleted, [_food]),
    );

    blocTest<DecksBloc, DecksState>(
      'puts it back in its place and explains when the delete fails',
      build: () {
        final created = bloc([]);
        decks.deleteFailure = const CacheFailure('disk full');
        return created;
      },
      seed: () => ready([_core, _food], studied: {'es-food'}),
      act: (bloc) async {
        final done = Completer<bool>();
        bloc.add(DeckDeleteConfirmed(_core, done));
        expect(await done.future, isFalse);
      },
      expect: () => [
        ready([_food], studied: {'es-food'}),
        ready(
          [_core, _food],
          studied: {'es-food'},
        ).copyWith(notice: "Couldn't delete “Core”: disk full"),
      ],
    );
  });
}
