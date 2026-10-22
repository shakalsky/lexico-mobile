import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexico/core/error/failure.dart';
import 'package:lexico/core/result/result.dart';
import 'package:lexico/core/theme/app_theme.dart';
import 'package:lexico/features/decks/domain/entities/deck.dart';
import 'package:lexico/features/decks/domain/usecases/create_deck.dart';
import 'package:lexico/features/decks/domain/usecases/get_decks.dart';
import 'package:lexico/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:lexico/features/decks/presentation/pages/decks_page.dart';
import 'package:lexico/features/vocabulary/domain/usecases/add_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/edit_word.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_deck_words.dart';
import 'package:lexico/features/vocabulary/domain/usecases/get_studied_deck_ids.dart';
import 'package:lexico/features/vocabulary/domain/usecases/set_deck_studied.dart';

import '../../../helpers/fake_decks_repository.dart';
import '../../../helpers/fake_vocabulary_repository.dart';
import '../../../helpers/fixtures.dart';

final _core = testDeckEntity('es-en-core', name: 'Core');
final _food = testDeckEntity('es-food', name: 'Food', day: 9);

void main() {
  late FakeDecksRepository repository;
  late FakeVocabularyRepository vocabulary;

  /// The spinner animates forever, so `pumpAndSettle` would never return.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpDecks(
    WidgetTester tester, {
    required List<Result<List<Deck>>> decks,
    List<Result<Deck>>? created,
  }) async {
    repository = FakeDecksRepository(decks: decks, created: created);
    vocabulary = FakeVocabularyRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider(
          create: (_) => DecksBloc(
            getDecks: GetDecks(repository),
            getStudiedDeckIds: GetStudiedDeckIds(vocabulary),
            setDeckStudied: SetDeckStudied(vocabulary),
          )..add(const DecksRequested()),
          child: DecksView(
            createDeck: CreateDeck(repository),
            getDeckWords: GetDeckWords(vocabulary),
            addWord: AddWord(vocabulary),
            editWord: EditWord(vocabulary),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('lists every deck with its study switch', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_core, _food]),
      ],
    );

    expect(find.text('Core'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Español · added Oct 8, 2026'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('study-es-en-core')),
        matching: find.text('Studying'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('study-es-food')),
        matching: find.text('Study'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the switch turns studying on and off', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_core, _food]),
      ],
    );

    await tester.tap(find.byKey(const Key('study-es-food')));
    await settle(tester);
    expect(find.text('Studying'), findsNWidgets(2));
    expect(vocabulary.studiedIds, {'es-en-core', 'es-food'});

    await tester.tap(find.byKey(const Key('study-es-en-core')));
    await settle(tester);
    expect(find.text('Studying'), findsOneWidget);
    expect(vocabulary.studiedIds, {'es-food'});
  });

  testWidgets('tapping a deck opens its words', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_core, _food]),
      ],
    );
    vocabulary.deckWordResults['es-food'] = [
      Result.success([
        testWord(id: 'es-pan', question: 'el pan', answer: 'bread'),
      ]),
    ];

    await tester.tap(find.byKey(const Key('deck-es-food')));
    await tester.pumpAndSettle();

    expect(find.text('el pan'), findsOneWidget);
    expect(find.text('bread'), findsOneWidget);
    expect(find.text('Español · 1 word'), findsOneWidget);
  });

  testWidgets('tapping the study button does not open the deck', (
    tester,
  ) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_food]),
      ],
    );

    await tester.tap(find.byKey(const Key('study-es-food')));
    await tester.pumpAndSettle();

    expect(vocabulary.deckWordCalls, 0);
    expect(find.byKey(const Key('deck-es-food')), findsOneWidget);
  });

  testWidgets('a failed switch flips back and says why', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_core, _food]),
      ],
    );
    vocabulary.setStudiedFailure = const CacheFailure('disk full');

    await tester.tap(find.byKey(const Key('study-es-food')));
    await settle(tester);

    expect(find.text('Studying'), findsOneWidget);
    expect(find.text("Couldn't save: disk full"), findsOneWidget);
  });

  testWidgets('says so when there are no decks', (tester) async {
    await pumpDecks(tester, decks: [const Result.success([])]);

    expect(find.text('No decks yet'), findsOneWidget);
  });

  testWidgets('offers a retry when loading fails', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        const Result.failure(NetworkFailure('No connection.')),
        Result.success([_food]),
      ],
    );

    expect(find.text("Couldn't load decks"), findsOneWidget);
    expect(find.text('No connection.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(find.text('Food'), findsOneWidget);
    expect(repository.getCalls, 2);
  });

  testWidgets('pulling down reloads the list', (tester) async {
    await pumpDecks(
      tester,
      decks: [
        Result.success([_core]),
        Result.success([_core, _food]),
      ],
    );
    expect(find.text('Food'), findsNothing);

    await tester.fling(find.text('Core'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(repository.getCalls, 2);
  });

  group('new deck', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('new-deck')));
      await tester.pumpAndSettle();
    }

    testWidgets('creates a deck and adds it to the list', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core]),
        ],
        created: [Result.success(_food)],
      );

      await openSheet(tester);
      expect(find.text('New deck'), findsWidgets);

      await tester.enterText(find.byKey(const Key('new-deck-name')), 'Food');
      await tester.tap(find.text('Create deck'));
      await tester.pumpAndSettle();

      expect(find.text('Create deck'), findsNothing, reason: 'sheet closed');
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Created “Food”'), findsOneWidget);
      expect(repository.createCalls, [(name: 'Food', language: 'English')]);
      expect(repository.getCalls, 1, reason: 'no reload needed');
    });

    testWidgets('sends the language picked from the menu', (tester) async {
      await pumpDecks(
        tester,
        decks: [const Result.success([])],
        created: [Result.success(_food)],
      );

      await openSheet(tester);
      expect(find.text('English'), findsOneWidget, reason: 'the default');

      await tester.tap(find.byKey(const Key('new-deck-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Polski').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('new-deck-name')), 'Food');
      await tester.tap(find.text('Create deck'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, [(name: 'Food', language: 'Polski')]);
    });

    testWidgets('keeps the sheet open and explains a failure', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core]),
        ],
        created: [const Result.failure(NetworkFailure('No connection.'))],
      );

      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('new-deck-name')), 'Food');
      await tester.tap(find.text('Create deck'));
      await tester.pumpAndSettle();

      expect(find.text('No connection.'), findsOneWidget);
      expect(find.text('Create deck'), findsOneWidget);
    });

    testWidgets('asks for a name', (tester) async {
      await pumpDecks(tester, decks: [const Result.success([])]);

      await openSheet(tester);
      await tester.tap(find.text('Create deck'));
      await tester.pumpAndSettle();

      expect(find.text('Give the deck a name.'), findsOneWidget);
      expect(repository.createCalls, isEmpty);
    });

    testWidgets('closing the sheet changes nothing', (tester) async {
      await pumpDecks(
        tester,
        decks: [
          Result.success([_core]),
        ],
      );

      await openSheet(tester);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('Create deck'), findsNothing);
      expect(find.text('Core'), findsOneWidget);
      expect(repository.createCalls, isEmpty);
    });
  });
}
